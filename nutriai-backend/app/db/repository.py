from __future__ import annotations

from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.core.crypto import encrypt_value
from app.db.models import ChatMessageRecord, DietPlanRecord, GoalRecord, LabResultRecord, TrackingRecord, User
from app.services.okta_service import encrypt_access_token, serialize_cookies


def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_okta_sub(db: Session, okta_sub: str) -> Optional[User]:
    return db.query(User).filter(User.okta_sub == okta_sub).first()


def upsert_okta_user(
    db: Session,
    *,
    okta_sub: str,
    email: str,
    first_name: Optional[str],
    last_name: Optional[str],
    access_token: str,
    portal_patient: Dict[str, Any],
    portal_cookies,
) -> User:
    user = get_user_by_okta_sub(db, okta_sub)
    labcorp_pid = portal_patient.get("pid") or portal_patient.get("id")

    if user is None:
        user = User(
            email=email,
            okta_sub=okta_sub,
            first_name=first_name,
            last_name=last_name,
            labcorp_patient_id=int(labcorp_pid) if labcorp_pid else None,
        )
        db.add(user)
    else:
        user.email = email or user.email
        user.first_name = first_name or user.first_name
        user.last_name = last_name or user.last_name
        if labcorp_pid:
            user.labcorp_patient_id = int(labcorp_pid)

    user.okta_access_token_enc = encrypt_access_token(access_token)
    user.portal_session_cookies_enc = serialize_cookies(portal_cookies)
    db.commit()
    db.refresh(user)
    return user


def save_lab_results(db: Session, user_id: int, results: List[Dict[str, Any]]) -> None:
    db.query(LabResultRecord).filter(LabResultRecord.user_id == user_id).delete()
    for result in results:
        db.add(
            LabResultRecord(
                id=int(result["id"]),
                user_id=user_id,
                payload=result,
                test_date=result.get("test_date"),
            )
        )
    db.commit()


def get_lab_results(db: Session, user_id: int) -> List[Dict[str, Any]]:
    rows = (
        db.query(LabResultRecord)
        .filter(LabResultRecord.user_id == user_id)
        .order_by(LabResultRecord.test_date.desc())
        .all()
    )
    return [row.payload for row in rows]


def update_portal_cookies(db: Session, user: User, cookies_enc: str) -> None:
    user.portal_session_cookies_enc = cookies_enc
    db.commit()


def save_diet_plan(db: Session, user_id: int, plan: Dict[str, Any]) -> Dict[str, Any]:
    db.query(DietPlanRecord).filter(
        DietPlanRecord.user_id == user_id,
        DietPlanRecord.is_current.is_(True),
    ).update({"is_current": False})
    record = DietPlanRecord(user_id=user_id, payload=plan, is_current=True)
    db.add(record)
    db.commit()
    db.refresh(record)
    return plan


def get_current_diet_plan(db: Session, user_id: int) -> Optional[Dict[str, Any]]:
    row = (
        db.query(DietPlanRecord)
        .filter(DietPlanRecord.user_id == user_id, DietPlanRecord.is_current.is_(True))
        .order_by(DietPlanRecord.created_at.desc())
        .first()
    )
    return row.payload if row else None


def add_chat_message(
    db: Session,
    user_id: int,
    role: str,
    content: str,
    metadata: Optional[Dict] = None,
) -> Dict[str, Any]:
    record = ChatMessageRecord(
        user_id=user_id,
        role=role,
        content=content,
        message_metadata=metadata or {},
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return {
        "id": record.id,
        "role": record.role,
        "content": record.content,
        "timestamp": record.created_at.isoformat() + "Z",
        "metadata": record.message_metadata or {},
    }


def get_chat_history(db: Session, user_id: int) -> List[Dict[str, Any]]:
    rows = (
        db.query(ChatMessageRecord)
        .filter(ChatMessageRecord.user_id == user_id)
        .order_by(ChatMessageRecord.created_at.asc())
        .all()
    )
    return [
        {
            "id": row.id,
            "role": row.role,
            "content": row.content,
            "timestamp": row.created_at.isoformat() + "Z",
            "metadata": row.message_metadata or {},
        }
        for row in rows
    ]


def clear_chat_history(db: Session, user_id: int) -> None:
    db.query(ChatMessageRecord).filter(ChatMessageRecord.user_id == user_id).delete()
    db.commit()


def save_goals(db: Session, user_id: int, goals: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    db.query(GoalRecord).filter(GoalRecord.user_id == user_id).delete()
    for idx, goal in enumerate(goals):
        db.add(GoalRecord(user_id=user_id, payload=goal, priority=goal.get("priority", idx + 1)))
    db.commit()
    return goals


def get_goals(db: Session, user_id: int) -> Optional[List[Dict[str, Any]]]:
    rows = (
        db.query(GoalRecord)
        .filter(GoalRecord.user_id == user_id)
        .order_by(GoalRecord.priority.asc())
        .all()
    )
    if not rows:
        return None
    return [row.payload for row in rows]


def replace_tracking_entries(db: Session, user_id: int, entries: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    db.query(TrackingRecord).filter(TrackingRecord.user_id == user_id).delete()
    saved: List[Dict[str, Any]] = []
    for entry in sorted(entries, key=lambda e: e["date"]):
        record = TrackingRecord(user_id=user_id, date=entry["date"], payload=entry)
        db.add(record)
        db.flush()
        out = {**entry, "id": record.id, "user_id": user_id}
        record.payload = out
        saved.append(out)
    db.commit()
    return saved


def upsert_tracking_entry(db: Session, user_id: int, entry: Dict[str, Any]) -> Dict[str, Any]:
    date_str = entry["date"]
    existing = (
        db.query(TrackingRecord)
        .filter(TrackingRecord.user_id == user_id, TrackingRecord.date == date_str)
        .first()
    )
    if existing:
        merged = {**(existing.payload or {}), **entry, "id": existing.id, "user_id": user_id}
        existing.payload = merged
        db.commit()
        return merged

    record = TrackingRecord(user_id=user_id, date=date_str, payload={})
    db.add(record)
    db.flush()
    out = {**entry, "id": record.id, "user_id": user_id}
    record.payload = out
    db.commit()
    return out


def get_tracking_entries(db: Session, user_id: int, days: Optional[int] = None) -> List[Dict[str, Any]]:
    q = db.query(TrackingRecord).filter(TrackingRecord.user_id == user_id)
    rows = q.order_by(TrackingRecord.date.asc()).all()
    entries = [row.payload for row in rows]
    if days and days > 0 and entries:
        from datetime import date, timedelta

        cutoff = (date.today() - timedelta(days=days - 1)).isoformat()
        entries = [e for e in entries if e.get("date", "") >= cutoff]
    return entries
