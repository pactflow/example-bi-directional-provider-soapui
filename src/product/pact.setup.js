const controller = require("./product.controller");
const Product = require("./product");
const cp = require('child_process');

let revision;
let branch;
try {
    revision = cp
      .execSync('git rev-parse HEAD', { stdio: 'pipe' })
      .toString()
      .trim();
  } catch (Error) {
    throw new TypeError(
      "Couldn't find a git commit hash, is this a git directory?"
    );
  }
  
  try {
    branch = cp
      .execSync('git rev-parse --abbrev-ref HEAD', { stdio: 'pipe' })
      .toString()
      .trim();
  } catch (Error) {
    throw new TypeError("Couldn't find a git branch, is this a git directory?");
  }
  
const baseOpts = {
  logLevel: "INFO",
  provider: 'DefaultApi',
  providerBaseUrl: "http://localhost:8080",
  providerVersion: process.env.GIT_COMMIT ?? revision,
  providerVersionBranch: process.env.GIT_BRANCH ?? branch, // the recommended way of publishing verification results with the branch property
};

// Setup provider server to verify

const setupServer = () => {
  const express = require("express");
  const app = express();
  app.use(express.json());
  // const authMiddleware = require("../middleware/auth.middleware");
  // app.use(authMiddleware);
  app.use(require("./product.routes"));
  const server = app.listen("8080");
  return server;
};

const stateHandlers = {
  "products exists": () => {
    controller.repository.products = new Map([
      ["10", new Product({id:"10", name:"CREDIT_CARD", type:"28 Degrees", version:"v1", price: 53})],
    ]);
  },
  "products exist": () => {
    controller.repository.products = new Map([
    ["10", new Product({id:"10", name:"CREDIT_CARD", type:"28 Degrees", version:"v1", price: 53})],
    ]);
  },
  "a product with ID 10 exists": () => {
    controller.repository.products = new Map([
    ["10", new Product({id:"10", name:"CREDIT_CARD", type:"28 Degrees", version:"v1", price: 53})],
    ]);
  },
  "a product with ID 11 does not exist": () => {
    controller.repository.products = new Map();
  },
};

const requestFilter = (req, res, next) => {
  if (!req.headers["authorization"]) {
    next();
    return;
  }
  req.headers["authorization"] = `Bearer ${new Date().toISOString()}`;
  next();
};

module.exports = {
  baseOpts,
  setupServer,
  stateHandlers,
  requestFilter,
};
