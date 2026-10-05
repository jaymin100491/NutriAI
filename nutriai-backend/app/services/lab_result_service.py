"""
Lab result service — Labcorp portal sync with DB persistence.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.core.config import settings
from app.db import repository as repo
from app.db.models import User
from app.integrations.labcorp.adapter import to_canonical_lab_result
from app.integrations.labcorp.client import labcorp_client
from app.integrations.labcorp.portal_adapter import report_header_to_summary, report_to_detail
from app.integrations.labcorp.portal_client import portal_client
from app.db.mock_data import MOCK_LAB_RESULTS


def _sort_key(result: Dict[str, Any]) -> str:
    return result.get("test_date", "")


async def sync_labcorp_results_for_user(db: Session, user: User) -> List[Dict[str, Any]]:
    """Pull live results from Labcorp patient portal QA."""
    if settings.LABCORP_USE_MOCK:
        return await _sync_mock_results(db, user.id)

    if not user.portal_session_cookies_enc and not user.okta_access_token_enc:
        raise ValueError("No Labcorp portal session — please sign in again")

    cookies_enc = user.portal_session_cookies_enc
    if user.okta_access_token_enc:
        _, cookies_enc = await portal_client.refresh_portal_session(user.okta_access_token_enc)
        repo.update_portal_cookies(db, user, cookies_enc)

    summaries, cookies_enc = await labcorp_client.fetch_result_summaries_live(
        cookies_enc,
        user.okta_access_token_enc,
    )
    if cookies_enc and cookies_enc != user.portal_session_cookies_enc:
        repo.update_portal_cookies(db, user, cookies_enc)

    results: List[Dict[str, Any]] = []
    cookies = cookies_enc or user.portal_session_cookies_enc

    for summary in summaries:
        if not summary.is_detail_available:
            canonical = to_canonical_lab_result(summary, None, user.id)
            results.append(canonical)
            continue

        detail, cookies = await labcorp_client.fetch_result_detail_live(
            summary.id,
            cookies,
            user.okta_access_token_enc,
        )
        if cookies and cookies != user.portal_session_cookies_enc:
            repo.update_portal_cookies(db, user, cookies)
            user.portal_session_cookies_enc = cookies

        canonical = to_canonical_lab_result(summary, detail, user.id)
        results.append(canonical)

    results.sort(key=_sort_key, reverse=True)
    repo.save_lab_results(db, user.id, results)
    return results


def import_portal_results_for_user(
    db: Session,
    user: User,
    headers: List[Dict[str, Any]],
    reports: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Normalize portal JSON already fetched in the browser (patient-website-ui pattern)."""
    report_by_id = {}
    for report in reports:
        header = report.get("header") or report
        report_id = header.get("id")
        if report_id is not None:
            report_by_id[int(report_id)] = report

    results: List[Dict[str, Any]] = []
    for header in headers:
        summary = report_header_to_summary(header)
        detail = None
        if summary.is_detail_available:
            report = report_by_id.get(summary.id)
            if report:
                detail = report_to_detail(report)
        canonical = to_canonical_lab_result(summary, detail, user.id)
        results.append(canonical)

    results.sort(key=_sort_key, reverse=True)
    repo.save_lab_results(db, user.id, results)
    return results


async def _sync_mock_results(db: Session, user_id: int) -> List[Dict[str, Any]]:
    from app.db.seed_demo import DEMO_EMAIL, build_demo_lab_timeline

    user = repo.get_user_by_id(db, user_id)
    if user and user.email == DEMO_EMAIL:
        results = build_demo_lab_timeline(user_id)
        repo.save_lab_results(db, user_id, results)
        return results

    pid = labcorp_client.get_patient_pid(user_id)
    if not pid:
        legacy = [r for r in MOCK_LAB_RESULTS if r["user_id"] == user_id]
        if not legacy:
            legacy = build_demo_lab_timeline(user_id)
        repo.save_lab_results(db, user_id, legacy)
        return legacy

    summaries = await labcorp_client.fetch_result_summaries(pid)
    results = []
    for summary in summaries:
        detail = await labcorp_client.fetch_result_detail(summary.id, pid)
        results.append(to_canonical_lab_result(summary, detail, user_id))

    results.sort(key=_sort_key, reverse=True)
    repo.save_lab_results(db, user_id, results)
    return results


async def sync_lab_results(
    db: Session,
    user: User,
    health_system_id: str = "labcorp",
    source: Optional[str] = None,
) -> List[Dict[str, Any]]:
    if source == "mychart":
        raise ValueError("MyChart live sync coming soon — demo labs are loaded from your health timeline")
    return await sync_labcorp_results_for_user(db, user)


def get_lab_results_for_user(db: Session, user_id: int) -> List[Dict[str, Any]]:
    stored = repo.get_lab_results(db, user_id)
    if stored:
        return stored
    if settings.LABCORP_USE_MOCK:
        return [r for r in MOCK_LAB_RESULTS if r["user_id"] == user_id]
    return []


async def get_lab_results_async(db: Session, user_id: int) -> List[Dict[str, Any]]:
    return get_lab_results_for_user(db, user_id)


async def get_lab_result_by_id(db: Session, user_id: int, result_id: int) -> Optional[Dict[str, Any]]:
    results = get_lab_results_for_user(db, user_id)
    return next((r for r in results if r["id"] == result_id), None)


async def get_latest_lab_result(db: Session, user_id: int) -> Optional[Dict[str, Any]]:
    results = get_lab_results_for_user(db, user_id)
    if not results:
        return None
    nutrition_abnormal = [
        r for r in results
        if r.get("interpretation", {}) and r["interpretation"].get("abnormal_count", 0) > 0
    ]
    if nutrition_abnormal:
        return nutrition_abnormal[0]
    return results[0]


def get_nutrition_relevant_history(db: Session, user_id: int) -> List[Dict[str, Any]]:
    results = get_lab_results_for_user(db, user_id)
    return [
        r for r in results
        if any(t.get("nutrition_relevant") for t in r.get("results", {}).get("tests", []))
    ]
