const path = require("path");
const fs = require("fs");
const express = require("express");
const morgan = require("morgan");

const app = express();
const PORT = process.env.PORT || 3000;

const ROOT_DIR = path.join(__dirname, "..");
const DECL_PATH = path.join(ROOT_DIR, "examples", "decls", "esp32-led-test.decl");
const PUBLIC_DIR = path.join(ROOT_DIR, "public");

app.use(morgan("dev"));
app.use(express.json());
app.use(express.static(PUBLIC_DIR));

// Allow cross-origin requests from the Flutter dev server (e.g. http://localhost:xxxx).
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept"
  );
  res.header(
    "Access-Control-Allow-Methods",
    "GET, POST, PUT, PATCH, DELETE, OPTIONS"
  );
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  next();
});

function parseDecl(text) {
  const lines = text.split(/\r?\n/);

  const components = [];
  const schematics = [];

  let currentComponent = null;
  let currentSchematic = null;
  let inPinsBlock = false;
  let inAttributesBlock = false;

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;

    const compMatch = line.match(/^component\s+(\w+)\s*\{/);
    if (compMatch) {
      currentComponent = {
        name: compMatch[1],
        pins: [],
        attributes: {}
      };
      components.push(currentComponent);
      inPinsBlock = false;
      inAttributesBlock = false;
      continue;
    }

    if (line === "pins {") {
      inPinsBlock = true;
      inAttributesBlock = false;
      continue;
    }

    if (line === "attributes {") {
      inPinsBlock = false;
      inAttributesBlock = true;
      continue;
    }

    if (line === "}" || line === "};") {
      if (currentSchematic && line === "}") {
        currentSchematic = null;
      } else if (currentComponent && line === "}") {
        currentComponent = null;
      }
      inPinsBlock = false;
      inAttributesBlock = false;
      continue;
    }

    if (currentComponent) {
      if (inPinsBlock) {
        const pinMatch = line.match(/^(.+?):\s*(\w+)\s+as\s+(\w+)/);
        if (pinMatch) {
          currentComponent.pins.push({
            id: pinMatch[1].trim(),
            type: pinMatch[2].trim(),
            name: pinMatch[3].trim()
          });
        }
        continue;
      }

      if (inAttributesBlock) {
        const attrMatch = line.match(/^(\w+):\s*([\w]+)\s*=\s*(.+)$/);
        if (attrMatch) {
          const [, key, valueType, value] = attrMatch;
          currentComponent.attributes[key] = {
            type: valueType,
            value: value.replace(/;$/, "").trim()
          };
        }
        continue;
      }
    }

    const schMatch = line.match(/^schematic\s+(\w+)\s*\{/);
    if (schMatch) {
      currentSchematic = {
        name: schMatch[1],
        instances: [],
        nets: [],
        connections: []
      };
      schematics.push(currentSchematic);
      continue;
    }

    if (currentSchematic) {
      const instMatch = line.match(/^instance\s+(\w+):\s*(\w+)(\s*\{.*\})?/);
      if (instMatch) {
        const instance = {
          name: instMatch[1],
          component: instMatch[2],
          raw: line,
          attributes: {}
        };

        const overridesRaw = instMatch[3];
        if (overridesRaw) {
          const inner = overridesRaw.replace(/^\s*\{\s*/, "").replace(/\s*\}\s*$/, "");
          inner
            .split(",")
            .map((part) => part.trim())
            .filter(Boolean)
            .forEach((part) => {
              const ovMatch = part.match(/^(\w+)\s*=\s*(.+)$/);
              if (ovMatch) {
                const key = ovMatch[1];
                const value = ovMatch[2].replace(/;$/, "").trim();
                instance.attributes[key] = value;
              }
            });
        }

        currentSchematic.instances.push(instance);
        continue;
      }

      const netMatch = line.match(/^net\s+(\w+)/);
      if (netMatch) {
        currentSchematic.nets.push({
          name: netMatch[1]
        });
        continue;
      }

      const connMatch = line.match(/^connect\s+([\w\.]+)\s*--\s*net\s+(\w+)/);
      if (connMatch) {
        currentSchematic.connections.push({
          endpoint: connMatch[1],
          net: connMatch[2]
        });
        continue;
      }
    }
  }

  return {
    components,
    schematics
  };
}

app.get("/api/decl", (req, res) => {
  fs.readFile(DECL_PATH, "utf8", (err, data) => {
    if (err) {
      console.error("Failed to read DECL file:", err);
      return res.status(500).json({ error: "Failed to read DECL file" });
    }

    const parsed = parseDecl(data);
    res.json({
      filePath: DECL_PATH,
      parsed,
      raw: data
    });
  });
});

app.get("*", (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, "index.html"));
});

app.listen(PORT, () => {
  console.log(`DECL viewer server running on http://localhost:${PORT}`);
});

