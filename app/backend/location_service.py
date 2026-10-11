"""
行山腳 HikeHub · Dual-Source Location Service (SystemProvider + SimulatedProvider)
Authors: Member A (Interface Definition) & Member C (Dual-Source Interpolation & Check-in)

Design:
- LocationProvider base interface
- SystemProvider: Attempts QtPositioning QGeoPositionInfoSource (winrt on Windows)
- SimulatedProvider: Interpolates smoothly along the selected trail's `path` polyline
- Auto-fallback: If SystemProvider does not yield a valid coordinate within 3 seconds,
  automatically switches to SimulatedProvider and surfaces badge "示範模式 · 模擬定位"
  without popups or crashes.
"""
import math
import time
from typing import Any, Dict, List, Optional, Tuple


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate great-circle distance between two coordinates in kilometers."""
    r = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2.0) ** 2
    return 2.0 * r * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))


class LocationProvider:
    """Abstract interface for location providers."""
    def start(self) -> None:
        raise NotImplementedError

    def stop(self) -> None:
        raise NotImplementedError

    def get_position(self) -> Optional[Tuple[float, float]]:
        raise NotImplementedError


class SystemProvider(LocationProvider):
    """QtPositioning (winrt / system GPS) wrapper with non-blocking probe."""
    def __init__(self) -> None:
        self._source = None
        self._last_coord: Optional[Tuple[float, float]] = None
        self._started_at: float = 0.0

    def start(self) -> None:
        self._started_at = time.time()
        try:
            from PySide6.QtPositioning import QGeoPositionInfoSource
            self._source = QGeoPositionInfoSource.createDefaultSource(None)
            if self._source is not None:
                self._source.positionUpdated.connect(self._on_position_updated)
                self._source.startUpdates()
        except Exception:
            self._source = None

    def _on_position_updated(self, info: Any) -> None:
        try:
            coord = info.coordinate()
            if coord.isValid():
                self._last_coord = (float(coord.latitude()), float(coord.longitude()))
        except Exception:
            pass

    def stop(self) -> None:
        if self._source is not None:
            try:
                self._source.stopUpdates()
            except Exception:
                pass

    def get_position(self) -> Optional[Tuple[float, float]]:
        return self._last_coord

    def timed_out(self, timeout_sec: float = 3.0) -> bool:
        return (self._last_coord is None) and ((time.time() - self._started_at) >= timeout_sec)


class SimulatedProvider(LocationProvider):
    """
    Interpolates coordinates along the trail's polyline (`[[lat, lng], ...]`)
    so classroom/office demos advance smoothly along real Hong Kong mountain ridges.
    """
    def __init__(self, path: List[List[float]], steps_per_segment: int = 8) -> None:
        self.raw_path = path if len(path) >= 2 else [[22.2268, 114.2422], [22.2458, 114.2495]]
        self.steps_per_segment = max(2, steps_per_segment)
        self.interpolated_points: List[Tuple[float, float]] = self._build_interpolated(self.raw_path)
        self.cursor: int = 0

    def _build_interpolated(self, pts: List[List[float]]) -> List[Tuple[float, float]]:
        result: List[Tuple[float, float]] = []
        for i in range(len(pts) - 1):
            lat1, lng1 = float(pts[i][0]), float(pts[i][1])
            lat2, lng2 = float(pts[i + 1][0]), float(pts[i + 1][1])
            for s in range(self.steps_per_segment):
                ratio = s / float(self.steps_per_segment)
                result.append((lat1 + (lat2 - lat1) * ratio, lng1 + (lng2 - lng1) * ratio))
        result.append((float(pts[-1][0]), float(pts[-1][1])))
        return result

    def start(self) -> None:
        self.cursor = 0

    def stop(self) -> None:
        pass

    def step_forward(self, stride: int = 1) -> Tuple[float, float]:
        self.cursor = min(len(self.interpolated_points) - 1, self.cursor + stride)
        return self.interpolated_points[self.cursor]

    def get_position(self) -> Tuple[float, float]:
        return self.interpolated_points[self.cursor]

    @property
    def progress_ratio(self) -> float:
        if len(self.interpolated_points) <= 1:
            return 1.0
        return self.cursor / float(len(self.interpolated_points) - 1)


class DualLocationCoordinator:
    """
    Coordinates SystemProvider and SimulatedProvider with 3-second automatic fallback
    and tracks walked vs remaining polyline segments for StartPage.
    """
    def __init__(self) -> None:
        self.system_provider = SystemProvider()
        self.simulated_provider = SimulatedProvider([])
        self.is_simulated: bool = False
        self.active: bool = False
        self.walked_path: List[List[float]] = []
        self.full_path: List[List[float]] = []
        self.distance_km: float = 0.0

    def start_session(self, trail_path: List[List[float]]) -> Dict[str, Any]:
        self.full_path = trail_path if len(trail_path) >= 2 else [[22.2268, 114.2422], [22.2458, 114.2495]]
        self.system_provider.start()
        self.simulated_provider = SimulatedProvider(self.full_path, steps_per_segment=6)
        self.simulated_provider.start()
        self.is_simulated = False
        self.active = True
        first_pt = self.full_path[0]
        self.walked_path = [[float(first_pt[0]), float(first_pt[1])]]
        self.distance_km = 0.0
        return self.tick()

    def tick(self) -> Dict[str, Any]:
        if not self.active:
            return {}
        sys_pos = self.system_provider.get_position()
        if sys_pos is not None and not self.is_simulated:
            lat, lng = sys_pos
            mode_label = "系統定位 · GPS 已鎖定"
        else:
            if self.system_provider.timed_out(3.0) or sys_pos is None:
                self.is_simulated = True
            lat, lng = self.simulated_provider.step_forward(1)
            mode_label = "示範模式 · 模擬定位"

        prev_lat, prev_lng = self.walked_path[-1]
        step_dist = haversine_km(prev_lat, prev_lng, lat, lng)
        if step_dist > 0.001:
            self.distance_km += step_dist
            self.walked_path.append([round(lat, 6), round(lng, 6)])

        # Compute remaining path from closest index on full_path
        progress = self.simulated_provider.progress_ratio if self.is_simulated else 0.5
        split_idx = min(len(self.full_path) - 1, int(progress * (len(self.full_path) - 1)))
        remaining_path = [[lat, lng]] + self.full_path[split_idx + 1 :]

        return {
            "lat": round(lat, 6),
            "lng": round(lng, 6),
            "is_simulated": self.is_simulated,
            "mode_label": mode_label,
            "distance_km": round(self.distance_km, 2),
            "walked_path": self.walked_path,
            "remaining_path": remaining_path,
            "progress_ratio": round(progress, 2),
        }

    def stop_session(self) -> None:
        self.active = False
        self.system_provider.stop()
        self.simulated_provider.stop()
