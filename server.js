const fs = require("fs");
const http = require("http");
const path = require("path");

const root = __dirname;
const port = Number(process.env.PORT) || 8081;
const dataFile = process.env.CASINO_DATA_FILE || path.join(root, "data", "casino-world.json");

const emptyStore = () => ({
    members: [],
    transactions: [],
    partners: [],
    payouts: [],
    applications: []
});

const emptyDoc = () => ({
    rev: 0,
    store: emptyStore(),
    prices: null,
    gateways: null
});

const normalizeStore = (store) => {
    const next = store && typeof store === "object" ? store : emptyStore();
    ["members", "transactions", "partners", "payouts", "applications"].forEach((key) => {
        if (!Array.isArray(next[key])) {
            next[key] = [];
        }
    });
    return {
        members: next.members,
        transactions: next.transactions,
        partners: next.partners,
        payouts: next.payouts,
        applications: next.applications
    };
};

const normalizeDoc = (doc) => {
    const next = doc && typeof doc === "object" ? doc : emptyDoc();
    return {
        rev: Number.isFinite(Number(next.rev)) ? Number(next.rev) : 0,
        store: normalizeStore(next.store),
        prices: next.prices && typeof next.prices === "object" ? next.prices : null,
        gateways: next.gateways && typeof next.gateways === "object" ? next.gateways : null
    };
};

const loadDoc = () => {
    try {
        return normalizeDoc(JSON.parse(fs.readFileSync(dataFile, "utf8")));
    } catch (error) {
        return emptyDoc();
    }
};

let doc = loadDoc();
const streams = new Set();

const saveDoc = () => {
    fs.mkdirSync(path.dirname(dataFile), { recursive: true });
    const temp = dataFile + ".tmp";
    fs.writeFileSync(temp, JSON.stringify(doc));
    fs.renameSync(temp, dataFile);
};

const sendJson = (res, status, body) => {
    const payload = JSON.stringify(body);
    res.writeHead(status, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, PUT, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
    });
    res.end(payload);
};

const broadcast = () => {
    const payload = "data: " + JSON.stringify(doc) + "\n\n";
    streams.forEach((res) => {
        res.write(payload);
    });
};

const readBody = (req) => new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
        size += chunk.length;
        if (size > 25 * 1024 * 1024) {
            reject(new Error("too large"));
            req.destroy();
            return;
        }
        chunks.push(chunk);
    });
    req.on("end", () => {
        try {
            const text = Buffer.concat(chunks).toString("utf8");
            resolve(text ? JSON.parse(text) : {});
        } catch (error) {
            reject(error);
        }
    });
    req.on("error", reject);
});

const types = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".s": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".svg": "image/svg+xml",
    ".webp": "image/webp",
    ".ico": "image/x-icon"
};

const serveFile = (res, urlPath) => {
    const clean = decodeURIComponent(urlPath.split("?")[0]);
    const relative = clean === "/" ? "index.html" : clean.replace(/^\/+/, "");
    const filePath = path.normalize(path.join(root, relative));
    if (!filePath.startsWith(root)) {
        res.writeHead(403);
        res.end();
        return;
    }
    fs.readFile(filePath, (error, body) => {
        if (error) {
            res.writeHead(404);
            res.end("Not found");
            return;
        }
        res.writeHead(200, {
            "Content-Type": types[path.extname(filePath).toLowerCase()] || "application/octet-stream",
            "Cache-Control": "no-store"
        });
        res.end(body);
    });
};

const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    if (req.method === "OPTIONS" && url.pathname.startsWith("/api/db")) {
        res.writeHead(204, {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, PUT, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type"
        });
        res.end();
        return;
    }
    if (url.pathname === "/api/db" && req.method === "GET") {
        sendJson(res, 200, doc);
        return;
    }
    if (url.pathname === "/api/db/stream" && req.method === "GET") {
        res.writeHead(200, {
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*"
        });
        res.write("data: " + JSON.stringify(doc) + "\n\n");
        streams.add(res);
        req.on("close", () => streams.delete(res));
        return;
    }
    if (url.pathname === "/api/db" && req.method === "PUT") {
        readBody(req).then((body) => {
            if (Number(body.baseRev) !== doc.rev) {
                sendJson(res, 409, doc);
                return;
            }
            doc = normalizeDoc({
                rev: doc.rev + 1,
                store: body.store,
                prices: body.prices,
                gateways: body.gateways
            });
            saveDoc();
            broadcast();
            sendJson(res, 200, doc);
        }).catch(() => {
            sendJson(res, 400, { error: "The database update could not be read." });
        });
        return;
    }
    if (req.method === "GET") {
        serveFile(res, url.pathname);
        return;
    }
    res.writeHead(405);
    res.end();
});

server.listen(port, "0.0.0.0", () => {
    console.log("Casino World database http://127.0.0.1:" + port + "/api/db");
});
