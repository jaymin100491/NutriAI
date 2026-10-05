"""
Live Labcorp patient portal API client.
Uses portal session cookies + optional Okta Bearer re-login.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

import httpx

from app.core.config import settings
from app.integrations.labcorp.models import LabcorpResultDetail, LabcorpResultSummary
from app.integrations.labcorp.portal_adapter import report_header_to_summary, report_to_detail
from app.services.okta_service import (
    decrypt_access_token,
    deserialize_cookies,
    build_cookie_header,
    portal_login,
    serialize_cookies,
)

logger = logging.getLogger(__name__)

RESULTS_HEADERS_PATH = "/protected/patients/current/linkedAccounts/results/headers/all"


class LabcorpPortalClient:
    def __init__(self, base_url: Optional[str] = None):
        self.base_url = (base_url or settings.LABCORP_PORTAL_API_URL).rstrip("/")

    def _client_with_session(self, cookies_enc: Optional[str]) -> httpx.AsyncClient:
        cookies = deserialize_cookies(cookies_enc) if cookies_enc else httpx.Cookies()
        headers = {"Accept": "application/json"}
        cookie_header = build_cookie_header(cookies)
        if cookie_header:
            headers["Cookie"] = cookie_header
        return httpx.AsyncClient(
            base_url=self.base_url,
            timeout=45.0,
            headers=headers,
        )

    async def refresh_portal_session(self, access_token_enc: str) -> tuple[Dict[str, Any], str]:
        token = decrypt_access_token(access_token_enc)
        patient, cookies = await portal_login(token)
        return patient, serialize_cookies(cookies)

    async def fetch_result_summaries(
        self,
        cookies_enc: Optional[str],
        access_token_enc: Optional[str],
    ) -> tuple[List[LabcorpResultSummary], Optional[str]]:
        cookies_enc, headers = await self._fetch_with_auth_retry(cookies_enc, access_token_enc)
        summaries = [report_header_to_summary(item) for item in headers]
        return summaries, cookies_enc

    async def fetch_result_detail(
        self,
        result_id: int,
        cookies_enc: Optional[str],
        access_token_enc: Optional[str],
    ) -> tuple[Optional[LabcorpResultDetail], Optional[str]]:
        cookies_enc, _ = await self._fetch_with_auth_retry(cookies_enc, access_token_enc)
        path = f"/protected/patients/current/linkedAccounts/results/{result_id}"

        async with self._client_with_session(cookies_enc) as client:
            response = await client.get(path)
            if response.status_code in (401, 403) and access_token_enc:
                _, cookies_enc = await self.refresh_portal_session(access_token_enc)
                async with self._client_with_session(cookies_enc) as retry_client:
                    response = await retry_client.get(path)
            response.raise_for_status()
            report = response.json()

        return report_to_detail(report), cookies_enc

    async def _fetch_with_auth_retry(
        self,
        cookies_enc: Optional[str],
        access_token_enc: Optional[str],
    ) -> tuple[Optional[str], List[Dict[str, Any]]]:
        async def _get_headers(session_cookies: Optional[str]) -> List[Dict[str, Any]]:
            async with self._client_with_session(session_cookies) as client:
                response = await client.get(RESULTS_HEADERS_PATH)
                if response.status_code == 401:
                    raise PermissionError("Portal session expired")
                if response.status_code == 403:
                    raise ValueError(
                        "Labcorp denied access to lab results. "
                        "Confirm your QA account has completed identity verification "
                        "and has results visible in the patient portal."
                    )
                response.raise_for_status()
                return response.json()

        try:
            return cookies_enc, await _get_headers(cookies_enc)
        except PermissionError:
            if not access_token_enc:
                raise ValueError(
                    "Labcorp portal session expired — please sign in again"
                ) from None
            _, cookies_enc = await self.refresh_portal_session(access_token_enc)
            return cookies_enc, await _get_headers(cookies_enc)


portal_client = LabcorpPortalClient()
