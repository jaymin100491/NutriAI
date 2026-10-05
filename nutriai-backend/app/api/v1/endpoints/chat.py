from fastapi import APIRouter, Depends
from app.schemas.chat import ChatMessageRequest, ChatResponse, ChatHistoryResponse, ChatMessageResponse
from app.core.security import get_current_user
from app.db.store import clear_chat_history, get_chat_history
from app.services.ai_service import process_chat_message

router = APIRouter()


@router.post("", response_model=ChatResponse)
async def send_chat_message(
    request: ChatMessageRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Chat with your AI dietitian.

    Supports:
    - Ingredient swaps: "Change tofu to paneer"
    - Goal reprioritization: "Focus on blood sugar first, then cholesterol"
    - Plan regeneration: "Generate a new 7-day plan"
    - Nutrition Q&A
    """
    result = await process_chat_message(current_user["id"], request.message)
    return result


@router.get("/history", response_model=ChatHistoryResponse)
async def get_chat_history_endpoint(current_user: dict = Depends(get_current_user)):
    """Get chat conversation history."""
    messages = get_chat_history(current_user["id"])
    return {"messages": messages, "total": len(messages)}


@router.delete("/history")
async def clear_chat(current_user: dict = Depends(get_current_user)):
    """Clear chat history."""
    clear_chat_history(current_user["id"])
    return {"message": "Chat history cleared"}
