import ast

def verify(source: str, filename: str = "generated.py") -> str:
    """Compile + AST-parse generated Python. Empty string means syntax is valid."""
    try:
        compile(source, filename, "exec", dont_inherit=True)
        ast.parse(source, filename=filename, mode="exec")
        return ""
    except SyntaxError as exc:
        line = exc.lineno or 0
        col = exc.offset or 0
        msg = exc.msg or "syntax error"
        return f"{filename}:{line}:{col}: {msg}"
    except Exception as exc:
        return f"{filename}: {type(exc).__name__}: {exc}"
