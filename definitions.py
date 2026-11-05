import json
from datetime import date, timedelta

import psycopg2
import requests
from dagster import DailyPartitionsDefinition, Definitions, asset

API_URL = "https://data.cityofchicago.org/resource/ydr8-5enu.json"
PAGE_SIZE = 1000

daily = DailyPartitionsDefinition(start_date="2026-10-01")


def get_conn():
    return psycopg2.connect(
        host="localhost", port=5435, dbname="permits", user="permits", password="permits"
    )


def fetch_day(day: str) -> list[dict]:
    start = date.fromisoformat(day)
    end = start + timedelta(days=1)
    where = f"issue_date >= '{start.isoformat()}T00:00:00' AND issue_date < '{end.isoformat()}T00:00:00'"

    records, offset = [], 0
    while True:
        resp = requests.get(
            API_URL,
            params={
                "$where": where,
                "$order": "permit_",  # stable order so paging doesn't skip or duplicate rows
                "$limit": PAGE_SIZE,
                "$offset": offset,
            },
            timeout=60,
        )
        resp.raise_for_status()
        page = resp.json()
        records.extend(page)
        if len(page) < PAGE_SIZE:
            return records
        offset += PAGE_SIZE


@asset(partitions_def=daily)
def raw_permits(context):
    day = context.partition_key
    records = fetch_day(day)

    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("create schema if not exists raw")
        cur.execute("""
            create table if not exists raw.permits (
                partition_date date not null,
                loaded_at timestamptz not null default now(),
                payload jsonb not null
            )
        """)
        cur.execute("delete from raw.permits where partition_date = %s", (day,))
        cur.executemany(
            "insert into raw.permits (partition_date, payload) values (%s, %s)",
            [(day, json.dumps(r)) for r in records],
        )
    context.log.info(f"Loaded {len(records)} permits for {day}")


defs = Definitions(assets=[raw_permits])
