"""
行山腳 HikeHub · Background Worker Thread Pool (L2/L3 Async Execution)
Author: Member B (App Framework & Auth)

Rule 4: All network / database calls run in QThreadPool via Worker Runnable
and emit Signals back to the main GUI thread so the UI never freezes.
"""
import traceback
from typing import Any, Callable
from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal, Slot


class WorkerSignals(QObject):
    finished = Signal(object)
    error = Signal(str)


class AsyncWorker(QRunnable):
    def __init__(self, fn: Callable[..., Any], *args: Any, **kwargs: Any) -> None:
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()

    @Slot()
    def run(self) -> None:
        try:
            result = self.fn(*self.args, **self.kwargs)
            self.signals.finished.emit(result)
        except Exception as exc:
            tb = traceback.format_exc()
            self.signals.error.emit(f"{exc}\n{tb}")


def run_in_background(
    fn: Callable[..., Any],
    on_success: Callable[[Any], None],
    on_error: Callable[[str], None] = lambda msg: None,
    *args: Any,
    **kwargs: Any,
) -> None:
    worker = AsyncWorker(fn, *args, **kwargs)
    worker.signals.finished.connect(on_success)
    worker.signals.error.connect(on_error)
    QThreadPool.globalInstance().start(worker)
