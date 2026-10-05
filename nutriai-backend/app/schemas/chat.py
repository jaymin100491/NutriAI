from pydantic import BaseModel
from typing import List, Optional, Any


class ChatMessageRequest(BaseModel):
    message: str


class ChatMessageResponse(BaseModel):
    id: int
    role: str
    content: str
    timestamp: str
    metadata: Optional[dict] = None


class ChatResponse(BaseModel):
    response: str
    plan_modified: bool = False
    goals_updated: bool = False
    suggestions: List[str] = []
    updated_plan_id: Optional[int] = None


class ChatHistoryResponse(BaseModel):
    messages: List[ChatMessageResponse]
    total: int
