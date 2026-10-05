"""
Labcorp API client — live patient portal (QA) or mock sample data.
"""
from __future__ import annotations

from typing import List, Optional, Tuple

from app.core.config import settings
from app.integrations.labcorp.models import LabcorpResultDetail, LabcorpResultSummary
from app.integrations.labcorp.portal_client import portal_client
from app.integrations.labcorp.sample_data import (
    LABCORP_RESULT_DETAILS,
    LABCORP_RESULT_SUMMARIES,
    USER_LABCORP_PID_MAP,
)


class LabcorpClient:
    def __init__(self, use_mock: Optional[bool] = None):
        self.use_mock = settings.LABCORP_USE_MOCK if use_mock is None else use_mock

    def get_patient_pid(self, user_id: int, labcorp_patient_id: Optional[int] = None) -> Optional[int]:
        if labcorp_patient_id:
            return labcorp_patient_id
        return USER_LABCORP_PID_MAP.get(int(user_id))

    async def fetch_result_summaries_live(
        self,
        cookies_enc: Optional[str],
        access_token_enc: Optional[str],
    ) -> Tuple[List[LabcorpResultSummary], Optional[str]]:
        return await portal_client.fetch_result_summaries(cookies_enc, access_token_enc)

    async def fetch_result_detail_live(
        self,
        result_id: int,
        cookies_enc: Optional[str],
        access_token_enc: Optional[str],
    ) -> Tuple[Optional[LabcorpResultDetail], Optional[str]]:
        return await portal_client.fetch_result_detail(result_id, cookies_enc, access_token_enc)

    async def fetch_result_summaries(self, pid: int) -> List[LabcorpResultSummary]:
        if not self.use_mock:
            raise RuntimeError("Use fetch_result_summaries_live with portal credentials")

        return [
            LabcorpResultSummary(**item)
            for item in LABCORP_RESULT_SUMMARIES
            if item["pid"] == pid
        ]

    async def fetch_result_detail(self, result_id: int, pid: int) -> Optional[LabcorpResultDetail]:
        if not self.use_mock:
            raise RuntimeError("Use fetch_result_detail_live with portal credentials")

        raw = LABCORP_RESULT_DETAILS.get(result_id)
        if not raw or raw.get("pid") != pid:
            return None
        return LabcorpResultDetail(**raw)


labcorp_client = LabcorpClient()
