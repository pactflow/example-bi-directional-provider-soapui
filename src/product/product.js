class Product {
  constructor({ id, name, type, price, version }) {
    if (!id || !name || !price ) {
      throw new Error("invalid product object");
    }
    this.id = id;
    this.name = name;
    this.type = type ?? "default";
    this.price = price;
    this.version = version ?? "v1";
  }
}

module.exports = Product;
