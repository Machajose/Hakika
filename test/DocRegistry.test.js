const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DocRegistry", function () {
  let registry, owner, issuer, stranger;
  const h1 = ethers.keccak256(ethers.toUtf8Bytes("doc-1"));
  const h2 = ethers.keccak256(ethers.toUtf8Bytes("doc-2"));
  const h3 = ethers.keccak256(ethers.toUtf8Bytes("doc-3"));
  const unknown = ethers.keccak256(ethers.toUtf8Bytes("never-issued"));

  beforeEach(async () => {
    [owner, issuer, stranger] = await ethers.getSigners();
    const F = await ethers.getContractFactory("DocRegistry");
    registry = await F.deploy();
    await registry.waitForDeployment();
    await registry.setIssuer(issuer.address, true);
  });

  it("owner is an issuer by default", async () => {
    expect(await registry.isIssuer(owner.address)).to.equal(true);
  });

  it("an issuer can anchor a hash and anyone can verify it", async () => {
    await registry.connect(issuer).anchor(h1);
    const r = await registry.connect(stranger).verify(h1);
    expect(r.exists).to.equal(true);
    expect(r.revoked).to.equal(false);
    expect(r.issuer).to.equal(issuer.address);
    expect(r.issuedAt).to.be.greaterThan(0n);
  });

  it("unknown hash is reported as not existing", async () => {
    const r = await registry.verify(unknown);
    expect(r.exists).to.equal(false);
    expect(r.issuedAt).to.equal(0n);
  });

  it("a stranger cannot anchor", async () => {
    await expect(registry.connect(stranger).anchor(h1)).to.be.revertedWithCustomError(registry, "NotIssuer");
  });

  it("cannot anchor the same hash twice", async () => {
    await registry.connect(issuer).anchor(h1);
    await expect(registry.connect(issuer).anchor(h1)).to.be.revertedWithCustomError(registry, "AlreadyAnchored");
  });

  it("batch anchoring records many hashes at once", async () => {
    await registry.connect(issuer).anchorBatch([h1, h2, h3]);
    for (const h of [h1, h2, h3]) {
      expect((await registry.verify(h)).exists).to.equal(true);
    }
  });

  it("empty batch is rejected", async () => {
    await expect(registry.connect(issuer).anchorBatch([])).to.be.revertedWithCustomError(registry, "EmptyBatch");
  });

  it("revoking marks the document revoked but keeps its history", async () => {
    await registry.connect(issuer).anchor(h1);
    await registry.connect(issuer).revoke(h1);
    const r = await registry.verify(h1);
    expect(r.exists).to.equal(true);
    expect(r.revoked).to.equal(true);
    expect(r.revokedAt).to.be.greaterThan(0n);
  });

  it("cannot revoke an unknown or already-revoked hash", async () => {
    await expect(registry.connect(issuer).revoke(unknown)).to.be.revertedWithCustomError(registry, "NotFound");
    await registry.connect(issuer).anchor(h1);
    await registry.connect(issuer).revoke(h1);
    await expect(registry.connect(issuer).revoke(h1)).to.be.revertedWithCustomError(registry, "AlreadyRevoked");
  });

  it("owner can remove an issuer, who then loses write access", async () => {
    await registry.setIssuer(issuer.address, false);
    await expect(registry.connect(issuer).anchor(h1)).to.be.revertedWithCustomError(registry, "NotIssuer");
  });

  it("only owner can manage issuers or transfer ownership", async () => {
    await expect(registry.connect(stranger).setIssuer(stranger.address, true)).to.be.revertedWithCustomError(registry, "NotOwner");
    await expect(registry.connect(stranger).transferOwnership(stranger.address)).to.be.revertedWithCustomError(registry, "NotOwner");
  });

  it("ownership can be transferred", async () => {
    await registry.transferOwnership(stranger.address);
    expect(await registry.owner()).to.equal(stranger.address);
    await expect(registry.setIssuer(owner.address, false)).to.be.revertedWithCustomError(registry, "NotOwner");
  });
});
