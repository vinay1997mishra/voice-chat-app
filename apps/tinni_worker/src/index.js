export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return Response.json({
        ok: true,
        service: "tinni-star-api",
        message: "Tinni Star API online",
        version: "0.1.0"
      });
    }

    if (url.pathname === "/") {
      return Response.json({
        ok: true,
        service: "tinni-star-api",
        message: "Tinni Star backend worker"
      });
    }

    return Response.json({ ok: false, error: "Not found" }, { status: 404 });
  }
};
