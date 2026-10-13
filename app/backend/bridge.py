"""
行山腳 HikeHub · QML-Python Bridge (L2 Bridge Layer)
Author: Member B (App Framework & Auth)

Exposes service layer capabilities to QML as Slots, Properties, and Signals.
Views (L1) only talk to `api` (ApiBridge instance) and never import SQL or supabase-py.
"""
from typing import Any, Dict, List, Optional
from PySide6.QtCore import QObject, Property, Signal, Slot, QTimer

from app.backend.auth_service import AuthService
from app.backend import trail_service, post_service, social_service
from app.backend.location_service import DualLocationCoordinator


class ApiBridge(QObject):
    # Auth & Navigation Signals
    authChanged = Signal()
    loginError = Signal(str)
    toastMessage = Signal(str)
    navigateToTabRequested = Signal(int)
    startTrailRequested = Signal(str)

    # Data Refresh Signals
    homeDataChanged = Signal()
    trailsChanged = Signal()
    trailDetailChanged = Signal()
    postsChanged = Signal()
    postDetailChanged = Signal()
    profileDataChanged = Signal()

    # StartPage (Map + GPS/Simulated Tracking) Signals
    hikeSessionChanged = Signal()

    def __init__(self, parent: Optional[QObject] = None) -> None:
        super().__init__(parent)
        self._auth = AuthService()
        self._loc = DualLocationCoordinator()

        # Cached state for QML binding
        self._featured_trails: List[Dict[str, Any]] = []
        self._nearby_trails: List[Dict[str, Any]] = []
        self._hot_posts: List[Dict[str, Any]] = []
        self._trails: List[Dict[str, Any]] = []
        self._current_trail: Dict[str, Any] = {}
        self._moment_posts: List[Dict[str, Any]] = []
        self._question_posts: List[Dict[str, Any]] = []
        self._current_post: Dict[str, Any] = {}
        self._my_posts: List[Dict[str, Any]] = []
        self._my_fav_trails: List[Dict[str, Any]] = []
        self._my_fav_posts: List[Dict[str, Any]] = []
        self._profile_stats: Dict[str, int] = {"post_count": 0, "favorite_count": 0, "trip_count": 0}

        # Hike session state ("idle" | "active" | "summary")
        self._hike_state: str = "idle"
        self._hike_trail: Dict[str, Any] = {}
        self._hike_elapsed_sec: int = 0
        self._hike_distance_km: float = 0.0
        self._hike_checked_ids: List[str] = []
        self._hike_photos: List[str] = []
        self._hike_mode_label: str = "系統定位待機中"
        self._hike_current_lat: float = 22.2369
        self._hike_current_lng: float = 114.2431
        self._hike_walked_path: List[List[float]] = []
        self._hike_remaining_path: List[List[float]] = []

        self._timer = QTimer(self)
        self._timer.setInterval(1500)
        self._timer.timeout.connect(self._on_hike_timer_tick)

        # Preload initial trail for StartPage preview
        all_t = trail_service.list_trails()
        if all_t:
            self._hike_trail = trail_service.get_trail_detail(all_t[0]["id"])
            if self._hike_trail.get("path"):
                self._hike_current_lat = float(self._hike_trail["path"][0][0])
                self._hike_current_lng = float(self._hike_trail["path"][0][1])
                self._hike_remaining_path = self._hike_trail["path"]

    # -----------------------------------------------------------------------
    # Environment & Auth Properties / Slots
    # -----------------------------------------------------------------------
    @Property(bool, notify=authChanged)
    def isLoggedIn(self) -> bool:
        return self._auth.current_user is not None

    @Property("QVariantMap", notify=authChanged)
    def currentUser(self) -> Dict[str, Any]:
        return self._auth.current_user or {}

    @Property("QVariantMap", constant=True)
    def envStatus(self) -> Dict[str, Any]:
        return self._auth.get_env_status()

    @Property("QVariantList", constant=True)
    def presetAccounts(self) -> List[Dict[str, str]]:
        return self._auth.get_preset_accounts()

    @Slot(str, str)
    def signIn(self, email: str, password: str) -> None:
        res = self._auth.sign_in(email, password)
        if not res.get("ok"):
            self.loginError.emit(res.get("error", "登錄失敗"))
            return
        self.refreshAll()
        self.authChanged.emit()
        self.toastMessage.emit(f"歡迎回來，{self._auth.current_user.get('nickname', '山友')}！")

    @Slot()
    def signOut(self) -> None:
        if self._hike_state == "active":
            self._timer.stop()
            self._loc.stop_session()
            self._hike_state = "idle"
        self._auth.sign_out()
        self.authChanged.emit()

    @Slot(str, str, str)
    def updateProfile(self, nickname: str, bio: str, avatar_url: str) -> None:
        res = self._auth.update_profile(nickname, bio, avatar_url)
        if res.get("ok"):
            self.authChanged.emit()
            self.refreshProfileData()
            self.refreshCommunity()
            self.toastMessage.emit("個人資料已更新")
        else:
            self.toastMessage.emit(res.get("error", "更新失敗"))

    @Slot()
    def refreshAll(self) -> None:
        self.refreshHome()
        self.filterTrails("全部", 0, "全部", "")
        self.refreshCommunity()
        self.refreshProfileData()

    # -----------------------------------------------------------------------
    # Home & Trails Properties / Slots
    # -----------------------------------------------------------------------
    @Property("QVariantList", notify=homeDataChanged)
    def featuredTrails(self) -> List[Dict[str, Any]]:
        return self._featured_trails

    @Property("QVariantList", notify=homeDataChanged)
    def nearbyTrails(self) -> List[Dict[str, Any]]:
        return self._nearby_trails

    @Property("QVariantList", notify=homeDataChanged)
    def hotPosts(self) -> List[Dict[str, Any]]:
        return self._hot_posts

    @Property("QVariantList", notify=trailsChanged)
    def trailsList(self) -> List[Dict[str, Any]]:
        return self._trails

    @Property("QVariantMap", notify=trailDetailChanged)
    def currentTrail(self) -> Dict[str, Any]:
        return self._current_trail

    @Slot()
    def refreshHome(self) -> None:
        uid = (self._auth.current_user or {}).get("id")
        feed = trail_service.get_home_feed(current_user_id=uid)
        self._featured_trails = feed["featured_trails"]
        self._nearby_trails = feed["nearby_trails"]
        self._hot_posts = feed["hot_posts"]
        self.homeDataChanged.emit()

    @Slot(str, int, str, str)
    def filterTrails(self, region: str, difficulty: int, duration_bucket: str, keyword: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        self._trails = trail_service.list_trails(
            region=region,
            difficulty=difficulty,
            duration_bucket=duration_bucket,
            keyword=keyword,
            current_user_id=uid,
        )
        self.trailsChanged.emit()

    @Slot(str)
    def loadTrailDetail(self, trail_id: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        self._current_trail = trail_service.get_trail_detail(trail_id, current_user_id=uid)
        # Also load related moments/trips for this trail
        self._current_trail["related_posts"] = post_service.list_posts(
            post_type="all", trail_id=trail_id, current_user_id=uid
        )[:4]
        self.trailDetailChanged.emit()

    # -----------------------------------------------------------------------
    # StartPage (Three-State Map + Dual-Source Location + Check-ins)
    # -----------------------------------------------------------------------
    @Property(str, notify=hikeSessionChanged)
    def hikeState(self) -> str:
        return self._hike_state

    @Property("QVariantMap", notify=hikeSessionChanged)
    def hikeTrail(self) -> Dict[str, Any]:
        return self._hike_trail

    @Property(str, notify=hikeSessionChanged)
    def hikeDurationText(self) -> str:
        mins, secs = divmod(self._hike_elapsed_sec, 60)
        hrs, mins = divmod(mins, 60)
        return f"{hrs:02d}:{mins:02d}:{secs:02d}"

    @Property(float, notify=hikeSessionChanged)
    def hikeDistanceKm(self) -> float:
        return round(self._hike_distance_km, 2)

    @Property(int, notify=hikeSessionChanged)
    def hikeCheckedCount(self) -> int:
        return len(self._hike_checked_ids)

    @Property(int, notify=hikeSessionChanged)
    def hikeTotalCheckpoints(self) -> int:
        return len(self._hike_trail.get("checkpoints", []))

    @Property(int, notify=hikeSessionChanged)
    def hikePhotoCount(self) -> int:
        return len(self._hike_photos)

    @Property(str, notify=hikeSessionChanged)
    def hikeModeLabel(self) -> str:
        return self._hike_mode_label

    @Property(float, notify=hikeSessionChanged)
    def hikeCurrentLat(self) -> float:
        return self._hike_current_lat

    @Property(float, notify=hikeSessionChanged)
    def hikeCurrentLng(self) -> float:
        return self._hike_current_lng

    @Property("QVariantList", notify=hikeSessionChanged)
    def hikeWalkedPath(self) -> List[List[float]]:
        return self._hike_walked_path

    @Property("QVariantList", notify=hikeSessionChanged)
    def hikeRemainingPath(self) -> List[List[float]]:
        return self._hike_remaining_path

    @Property("QVariantList", notify=hikeSessionChanged)
    def hikeCheckedIds(self) -> List[str]:
        return self._hike_checked_ids

    @Slot(str)
    def selectHikeTrail(self, trail_id: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        self._hike_trail = trail_service.get_trail_detail(trail_id, current_user_id=uid)
        path = self._hike_trail.get("path", [])
        if path:
            self._hike_current_lat = float(path[0][0])
            self._hike_current_lng = float(path[0][1])
            self._hike_remaining_path = path
            self._hike_walked_path = []
        self.hikeSessionChanged.emit()

    @Slot(str)
    def jumpToStartWithTrail(self, trail_id: str) -> None:
        self.selectHikeTrail(trail_id)
        self.navigateToTabRequested.emit(2)  # Tab index 2 = 出發

    @Slot()
    def startHike(self) -> None:
        if not self._hike_trail:
            all_t = trail_service.list_trails()
            if all_t:
                self.selectHikeTrail(all_t[0]["id"])
        path = self._hike_trail.get("path", [])
        snap = self._loc.start_session(path)
        self._hike_state = "active"
        self._hike_elapsed_sec = 0
        self._hike_distance_km = snap.get("distance_km", 0.0)
        self._hike_checked_ids = []
        self._hike_photos = []
        self._hike_current_lat = snap.get("lat", 22.2369)
        self._hike_current_lng = snap.get("lng", 114.2431)
        self._hike_mode_label = snap.get("mode_label", "示範模式 · 模擬定位")
        self._hike_walked_path = snap.get("walked_path", [])
        self._hike_remaining_path = snap.get("remaining_path", path)
        self._timer.start()
        self.hikeSessionChanged.emit()
        self.toastMessage.emit(f"已開始行山：{self._hike_trail.get('name', '')}")

    def _on_hike_timer_tick(self) -> None:
        if self._hike_state != "active":
            return
        self._hike_elapsed_sec += 15
        snap = self._loc.tick()
        if snap:
            self._hike_current_lat = snap["lat"]
            self._hike_current_lng = snap["lng"]
            self._hike_distance_km = snap["distance_km"]
            self._hike_mode_label = snap["mode_label"]
            self._hike_walked_path = snap["walked_path"]
            self._hike_remaining_path = snap["remaining_path"]
        self.hikeSessionChanged.emit()

    @Slot()
    def checkInNextPoint(self) -> None:
        cps = self._hike_trail.get("checkpoints", [])
        for cp in cps:
            if cp["id"] not in self._hike_checked_ids:
                self._hike_checked_ids.append(cp["id"])
                self.hikeSessionChanged.emit()
                self.toastMessage.emit(f"打卡成功：{cp['name']} ({len(self._hike_checked_ids)}/{len(cps)})")
                return
        self.toastMessage.emit("所有打卡點均已完成！")

    @Slot(str)
    def addHikePhoto(self, photo_url: str) -> None:
        chosen = photo_url.strip() if photo_url.strip() else self._hike_trail.get("cover_url", "")
        if chosen:
            self._hike_photos.append(chosen)
            self.hikeSessionChanged.emit()
            self.toastMessage.emit(f"已記錄沿途相片（共 {len(self._hike_photos)} 張）")

    @Slot()
    def finishHike(self) -> None:
        self._timer.stop()
        self._loc.stop_session()
        if self._hike_distance_km < 0.2:
            self._hike_distance_km = float(self._hike_trail.get("distance_km", 5.0))
        self._hike_state = "summary"
        self.hikeSessionChanged.emit()

    @Slot(bool, str)
    def completeHikeSettlement(self, publish_to_community: bool, note: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        if uid and publish_to_community:
            tname = self._hike_trail.get("name", "香港山徑")
            body_text = note.strip() or (
                f"完成【{tname}】行山打卡！全程 {self.hikeDistanceKm} km，"
                f"耗時 {self.hikeDurationText}，成功打卡 {self.hikeCheckedCount}/{self.hikeTotalCheckpoints} 個路標點。"
            )
            post_service.create_post(
                author_id=uid,
                post_type="trip",
                title=f"{tname} · 行山軌跡記錄",
                body=body_text,
                trail_id=self._hike_trail.get("id", "trail-01"),
                photos=self._hike_photos or [self._hike_trail.get("cover_url", "")],
                tags=["行山記錄", self._hike_trail.get("region", "香港行山")],
                trip_meta={
                    "distance_km": self.hikeDistanceKm,
                    "duration_sec": self._hike_elapsed_sec,
                    "ascent_m": self._hike_trail.get("ascent_m", 300),
                    "checked_count": self.hikeCheckedCount,
                    "total_checkpoints": self.hikeTotalCheckpoints,
                    "path": self._hike_walked_path or self._hike_trail.get("path", []),
                },
            )
            self.refreshCommunity()
            self.refreshHome()
            self.refreshProfileData()
            self.toastMessage.emit("行山記錄已發布至社區！")
        else:
            self.toastMessage.emit("行山記錄已保存至個人檔案")

        self._hike_state = "idle"
        self.hikeSessionChanged.emit()
        if publish_to_community:
            self.navigateToTabRequested.emit(3)  # Jump to Community Tab

    # -----------------------------------------------------------------------
    # Community, Post Detail & Social Interactions
    # -----------------------------------------------------------------------
    @Property("QVariantList", notify=postsChanged)
    def momentPosts(self) -> List[Dict[str, Any]]:
        return self._moment_posts

    @Property("QVariantList", notify=postsChanged)
    def questionPosts(self) -> List[Dict[str, Any]]:
        return self._question_posts

    @Property("QVariantMap", notify=postDetailChanged)
    def currentPost(self) -> Dict[str, Any]:
        return self._current_post

    @Slot()
    def refreshCommunity(self) -> None:
        uid = (self._auth.current_user or {}).get("id")
        self._moment_posts = post_service.list_posts(post_type="moment", current_user_id=uid)
        self._question_posts = post_service.list_posts(post_type="question", current_user_id=uid)
        self.postsChanged.emit()

    @Slot(str)
    def loadPostDetail(self, post_id: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        self._current_post = post_service.get_post_detail(post_id, current_user_id=uid)
        self.postDetailChanged.emit()

    @Slot(str, str, str, str, "QVariantList", "QVariantList")
    def publishPost(
        self,
        post_type: str,
        title: str,
        body: str,
        trail_id: str,
        photos: List[str],
        tags: List[str],
    ) -> None:
        uid = (self._auth.current_user or {}).get("id")
        if not uid:
            self.toastMessage.emit("請先登錄後再發布內容")
            return
        created = post_service.create_post(
            author_id=uid,
            post_type=post_type,
            title=title,
            body=body,
            trail_id=trail_id,
            photos=list(photos),
            tags=list(tags),
        )
        self.refreshCommunity()
        self.refreshHome()
        self.refreshProfileData()
        self.toastMessage.emit("發布成功！")

    @Slot(str, str, str)
    def editMyPost(self, post_id: str, title: str, body: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        if not uid:
            return
        post_service.update_post(post_id, uid, title, body)
        self.refreshCommunity()
        self.refreshProfileData()
        if self._current_post.get("id") == post_id:
            self.loadPostDetail(post_id)
        self.toastMessage.emit("動態已更新")

    @Slot(str)
    def deleteMyPost(self, post_id: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        if not uid:
            return
        if post_service.delete_post(post_id, uid):
            self.refreshCommunity()
            self.refreshHome()
            self.refreshProfileData()
            self.toastMessage.emit("動態已刪除")

    @Slot(str)
    def toggleLike(self, post_id: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        if not uid:
            self.toastMessage.emit("請先登錄")
            return
        social_service.toggle_like(post_id, uid)
        self.refreshCommunity()
        self.refreshHome()
        if self._current_post.get("id") == post_id:
            self.loadPostDetail(post_id)

    @Slot(str, str)
    def toggleFavorite(self, target_type: str, target_id: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        if not uid:
            self.toastMessage.emit("請先登錄")
            return
        res = social_service.toggle_favorite(target_type, target_id, uid)
        self.refreshCommunity()
        self.refreshHome()
        self.refreshProfileData()
        if target_type == "trail" and self._current_trail.get("id") == target_id:
            self.loadTrailDetail(target_id)
        elif target_type == "post" and self._current_post.get("id") == target_id:
            self.loadPostDetail(target_id)
        msg = "已加入收藏" if res.get("is_favorited") else "已取消收藏"
        self.toastMessage.emit(msg)

    @Slot(str, str, str)
    def addComment(self, post_id: str, body: str, parent_id: str = "") -> None:
        uid = (self._auth.current_user or {}).get("id")
        if not uid or not body.strip():
            return
        social_service.add_comment(post_id, uid, body, parent_id)
        self.loadPostDetail(post_id)
        self.refreshCommunity()
        self.toastMessage.emit("評論已發送")

    @Slot(str, str)
    def acceptAnswer(self, post_id: str, comment_id: str) -> None:
        uid = (self._auth.current_user or {}).get("id")
        if not uid:
            return
        if social_service.accept_comment(post_id, comment_id, uid):
            self.loadPostDetail(post_id)
            self.refreshCommunity()
            self.toastMessage.emit("已採納該山友回答！")
        else:
            self.toastMessage.emit("只有提問作者可採納回答，且每題僅限採納一次")

    # -----------------------------------------------------------------------
    # Profile Page Properties / Slots
    # -----------------------------------------------------------------------
    @Property("QVariantList", notify=profileDataChanged)
    def myPosts(self) -> List[Dict[str, Any]]:
        return self._my_posts

    @Property("QVariantList", notify=profileDataChanged)
    def myFavoriteTrails(self) -> List[Dict[str, Any]]:
        return self._my_fav_trails

    @Property("QVariantList", notify=profileDataChanged)
    def myFavoritePosts(self) -> List[Dict[str, Any]]:
        return self._my_fav_posts

    @Property("QVariantMap", notify=profileDataChanged)
    def profileStats(self) -> Dict[str, int]:
        return self._profile_stats

    @Slot()
    def refreshProfileData(self) -> None:
        uid = (self._auth.current_user or {}).get("id")
        if not uid:
            self._my_posts = []
            self._my_fav_trails = []
            self._my_fav_posts = []
            self._profile_stats = {"post_count": 0, "favorite_count": 0, "trip_count": 0}
            self.profileDataChanged.emit()
            return
        self._my_posts = post_service.list_posts(post_type="all", author_id=uid, current_user_id=uid)
        favs = social_service.get_user_favorites(uid)
        self._my_fav_trails = favs["trails"]
        self._my_fav_posts = favs["posts"]
        self._profile_stats = self._auth.get_profile_stats(uid)
        self.profileDataChanged.emit()
