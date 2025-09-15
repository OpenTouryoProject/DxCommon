# トレースとスパンの開始・終了をログに記録する仕組み

import string
import secrets

from agents import TracingProcessor, Trace, Span
from database import write_log

ALPHANUM = string.ascii_lowercase + string.digits 

# 各トレース（処理単位）に一意の ID を生成する。
def make_trace_id(tag: str) -> str:
    """
    Return a string of the form 'trace_<tag><random>',
    where the total length after 'trace_' is 32 chars.
    """
    tag += "0"
    pad_len = 32 - len(tag)
    random_suffix = ''.join(secrets.choice(ALPHANUM) for _ in range(pad_len))
    return f"trace_{tag}{random_suffix}"

# TracingProcessor を継承して、トレースやスパンの開始/終了を監視してログに書き込むクラス。
class LogTracer(TracingProcessor):

    # trace_id の中から タグ名だけを取り出す。
    def get_name(self, trace_or_span: Trace | Span) -> str | None:
        trace_id = trace_or_span.trace_id
        name = trace_id.split("_")[1]
        if '0' in name:
            return name.split("0")[0]
        else:
            return None

    # トレースが開始したとき → "Started: <trace.name>" をログDBに記録
    def on_trace_start(self, trace) -> None:
        name = self.get_name(trace)
        if name:
            write_log(name, "trace", f"Started: {trace.name}")

    # トレースが終了したとき → "Ended: <trace.name>" をログDBに記録。
    def on_trace_end(self, trace) -> None:
        name = self.get_name(trace)
        if name:
            write_log(name, "trace", f"Ended: {trace.name}")

    # スパンの開始ログ、Started span.span_dataの中身をログDBに記録。
    def on_span_start(self, span) -> None:
        name = self.get_name(span)
        type = span.span_data.type if span.span_data else "span"
        if name:
            message = "Started"
            if span.span_data:
                if span.span_data.type:
                    message += f" {span.span_data.type}"
                if hasattr(span.span_data, "name") and span.span_data.name:
                    message += f" {span.span_data.name}"
                if hasattr(span.span_data, "server") and span.span_data.server:
                    message += f" {span.span_data.server}"
            if span.error:
                message += f" {span.error}"
            write_log(name, type, message)

    # スパンの終了ログ、Ended span.span_dataの中身をログDBに記録。
    def on_span_end(self, span) -> None:
        name = self.get_name(span)
        type = span.span_data.type if span.span_data else "span"
        if name:
            message = "Ended"
            if span.span_data:
                if span.span_data.type:
                    
                    message += f" {span.span_data.type}"
                if hasattr(span.span_data, "name") and span.span_data.name:
                    message += f" {span.span_data.name}"
                if hasattr(span.span_data, "server") and span.span_data.server:
                    message += f" {span.span_data.server}"
            if span.error:
                message += f" {span.error}"
            write_log(name, type, message)

    # インターフェース上必要なメソッドだが、ここでは未実装。
    def force_flush(self) -> None:
        pass

    # インターフェース上必要なメソッドだが、ここでは未実装。
    def shutdown(self) -> None:
        pass