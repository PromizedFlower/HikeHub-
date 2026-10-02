"""
行山腳 HikeHub · Data Models & Serialization (L3 Service Contract)
Author: Member A (Data Architect)
All service functions return dict / list[dict] matching Supabase column names.
"""
from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List, Optional


class AppError(Exception):
    """Unified Service-Layer Error with code & human-readable message."""
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass
class ProfileModel:
    id: str
    email: str
    nickname: str
    bio: str = ""
    avatar_url: str = ""
    created_at: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class TrailModel:
    id: str
    name: str
    region: str
    difficulty: int
    distance_km: float
    ascent_m: int
    duration_min: int
    cover_url: str
    description: str
    path: List[List[float]] = field(default_factory=list)
    favorite_count: int = 0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class PostModel:
    id: str
    author_id: str
    type: str  # 'moment' | 'question' | 'trip'
    title: str
    body: str
    trail_id: Optional[str] = None
    meta: Dict[str, Any] = field(default_factory=dict)
    like_count: int = 0
    comment_count: int = 0
    favorite_count: int = 0
    created_at: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)
