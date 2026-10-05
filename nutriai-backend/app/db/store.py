"""
Runtime store — diet plans, chat, goals, and preferences persisted to database.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any, Dict, List, Optional

from app.db.database import SessionLocal
from app.db import repository as repo

_plan_id_counter = 1


def next_plan_id() -> int:
    global _plan_id_counter
    pid = _plan_id_counter
    _plan_id_counter += 1
    return pid


def get_user_plan(user_id: int) -> Optional[Dict[str, Any]]:
    db = SessionLocal()
    try:
        return repo.get_current_diet_plan(db, user_id)
    finally:
        db.close()


def set_user_plan(user_id: int, plan: Dict[str, Any]) -> Dict[str, Any]:
    db = SessionLocal()
    try:
        return repo.save_diet_plan(db, user_id, deepcopy(plan))
    finally:
        db.close()


def get_chat_history(user_id: int) -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        return repo.get_chat_history(db, user_id)
    finally:
        db.close()


def add_chat_message(user_id: int, role: str, content: str, metadata: Optional[Dict] = None) -> Dict[str, Any]:
    db = SessionLocal()
    try:
        return repo.add_chat_message(db, user_id, role, content, metadata)
    finally:
        db.close()


def clear_chat_history(user_id: int) -> None:
    db = SessionLocal()
    try:
        repo.clear_chat_history(db, user_id)
    finally:
        db.close()


def get_user_preferences(user_id: int) -> Dict[str, Any]:
    db = SessionLocal()
    try:
        return repo.get_user_preferences(db, user_id)
    finally:
        db.close()


def set_user_preferences(user_id: int, prefs: Dict[str, Any]) -> Dict[str, Any]:
    db = SessionLocal()
    try:
        return repo.save_user_preferences(db, user_id, prefs)
    finally:
        db.close()


def add_substitution_preference(user_id: int, swap_from: str, swap_to: str) -> None:
    prefs = get_user_preferences(user_id)
    prefs.setdefault("substitutions", {})[swap_from.lower()] = swap_to.lower()
    set_user_preferences(user_id, prefs)


def get_user_goals(user_id: int) -> Optional[List[Dict[str, Any]]]:
    db = SessionLocal()
    try:
        return repo.get_goals(db, user_id)
    finally:
        db.close()


def set_user_goals(user_id: int, goals: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        return repo.save_goals(db, user_id, deepcopy(goals))
    finally:
        db.close()
