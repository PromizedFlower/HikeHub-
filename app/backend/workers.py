"""
行山腳 HikeHub · Background Worker Thread Pool (L2/L3 Async Execution)
Author: Member B (App Framework & Auth)

Rule 4: network / database calls run in QThreadPool via Worker Runnable and
emit Signals back to the main GUI thread so the UI never freezes.

`ApiBridge` uses this pool for the startup 9-table cloud snapshot. A strong
reference to each worker is kept until its callback has actually run on the
GUI thread; otherwise CPython may collect the `WorkerSignals` QObject while
`QRunnable.run()` is still emitting, producing
"RuntimeError: Signal source has been deleted".
"""
import threading
from typing import Any, Callable, Set

from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal, Slot


class WorkerSignals(QObject):
    finished = Signal(object)
    error = Signal(str)


_ACTIVE_WORKERS: Set["AsyncWorker"] = set()
_ACTIVE_LOCK = threading.Lock()


class AsyncWorker(QRunnable):
    def __init__(self, fn: Callable[..., Any], *args: Any, **kwargs: Any) -> None:
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()
        self._finish_cb: Any = None
        self._fail_cb: Any = None

    @Slot()
    def run(self) -> None:
        try:
            result = self.fn(*self.args, **self.kwargs)
        except Exception as exc:
            # Tracebacks may embed URLs, anon keys or JWTs: never forward them.
            try:
                self.signals.error.emit(exc.__class__.__name__)
            except RuntimeError:
                pass
            return
        try:
            self.signals.finished.emit(result)
        except RuntimeError:
            # Qt is shutting down and already reaped the signal source.
            pass


def run_in_background(
    fn: Callable[..., Any],
    on_success: Callable[[Any], None],
    on_error: Callable[[str], None] = lambda msg: None,
    *args: Any,
    **kwargs: Any,
) -> None:
    worker = AsyncWorker(fn, *args, **kwargs)

    def _release() -> None:
        with _ACTIVE_LOCK:
            _ACTIVE_WORKERS.discard(worker)

    def _finish(result: Any) -> None:
        try:
            on_success(result)
        finally:
            _release()

    def _fail(message: str) -> None:
        try:
            on_error(message)
        finally:
            _release()

    # Keep both callables alive for the whole queued-connection lifetime.
    worker._finish_cb = _finish
    worker._fail_cb = _fail
    worker.signals.finished.connect(_finish)
    worker.signals.error.connect(_fail)
    with _ACTIVE_LOCK:
        _ACTIVE_WORKERS.add(worker)
    QThreadPool.globalInstance().start(worker)
