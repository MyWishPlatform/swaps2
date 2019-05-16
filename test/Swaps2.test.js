const {
  balance,
  BN,
  constants: { ZERO_ADDRESS },
  ether,
  expectEvent,
  shouldFail,
  time,
  time: { duration }
} = require("openzeppelin-test-helpers");

const chai = require("chai");
const { expect } = chai;
chai.use(require("bn-chai")(web3.utils.BN));

const Vault = artifacts.require("Vault");
const Swaps = artifacts.require("Swaps");
const Token = artifacts.require("TestToken");
const BNB = artifacts.require("BNB");

contract("Swaps2", ([owner, myWish, broker, orderOwner, ...accounts]) => {
  let now;
  let swaps;
  let vault;
  let baseToken;
  let quoteToken;
  let baseLimit = ether("1");
  let quoteLimit = ether("2");

  async function depositToken(swaps, id, token, amount, from) {
    await token.mint(from, amount);
    await token.approve(swaps.address, amount, { from });
    await swaps.deposit(id, token.address, amount, { from });
  }

  beforeEach(async () => {
    now = await time.latest();
    vault = await Vault.new();
    swaps = await Swaps.new();
    await vault.setSwaps(swaps.address);
    await swaps.setVault(vault.address);
    baseToken = await Token.new();
    quoteToken = await Token.new();
  });

  it("create simple order", async () => {
    const id = await swaps.createKey(accounts[0]);

    await swaps.createOrder(
      id,
      baseToken.address,
      quoteToken.address,
      baseLimit,
      quoteLimit,
      now.add(duration.minutes("1")),
      ZERO_ADDRESS,
      ether("0"),
      ether("0"),
      ZERO_ADDRESS,
      0,
      0,
      { from: orderOwner }
    );
  });

  it("create order with broker", async () => {
    const id = await swaps.createKey(accounts[0]);

    await swaps.createOrder(
      id,
      baseToken.address,
      quoteToken.address,
      baseLimit,
      quoteLimit,
      now.add(duration.minutes("1")),
      ZERO_ADDRESS,
      ether("0"),
      ether("0"),
      broker,
      100,
      250,
      { from: orderOwner }
    );
  });

  it("create order with broker and mywish broker", async () => {
    await swaps.setMyWishAddress(myWish, { from: owner });
    await swaps.setMyWishPercents(50, 70, { from: owner });

    const id = await swaps.createKey(accounts[0]);

    await swaps.createOrder(
      id,
      baseToken.address,
      quoteToken.address,
      baseLimit,
      quoteLimit,
      now.add(duration.minutes("1")),
      ZERO_ADDRESS,
      ether("0"),
      ether("0"),
      broker,
      100,
      250,
      { from: orderOwner }
    );
  });

  it("deposit to order with broker and mywish and check distribution", async () => {
    const myWishBasePercent = 50;
    const myWishQuotePercent = 70;
    const id = await swaps.createKey(accounts[0]);
    const brokerBasePercent = 100;
    const brokerQuotePercent = 250;

    await swaps.setMyWishAddress(myWish, { from: owner });
    await swaps.setMyWishPercents(myWishBasePercent, myWishQuotePercent, {
      from: owner
    });

    await swaps.createOrder(
      id,
      baseToken.address,
      quoteToken.address,
      baseLimit,
      quoteLimit,
      now.add(duration.minutes("1")),
      ZERO_ADDRESS,
      ether("0"),
      ether("0"),
      broker,
      brokerBasePercent,
      brokerQuotePercent,
      { from: orderOwner }
    );

    await depositToken(swaps, id, baseToken, baseLimit, accounts[1]);
    await depositToken(swaps, id, quoteToken, quoteLimit, accounts[2]);

    const myWishBaseToReceive = Math.floor(
      (baseLimit * myWishBasePercent) / 10000
    );
    expect(await baseToken.balanceOf(myWish)).to.eq.BN(myWishBaseToReceive);

    // const myWishQuoteToReceive = Math.floor(quoteLimit * myWishQuotePercent / 10000);
    // expect(await quoteToken.balanceOf(myWish)).to.eq.BN(myWishQuoteToReceive);
  });
});
