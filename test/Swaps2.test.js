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
chai.should();
chai.use(require("chai-bn")(BN));
chai.use(require("chai-as-promised"));

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
  const MAX_PERCENT = new BN("10000");

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
    const myWishBasePercent = new BN("50");
    const myWishQuotePercent = new BN("70");
    const id = await swaps.createKey(accounts[0]);
    const brokerBasePercent = new BN("100");
    const brokerQuotePercent = new BN("250");

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
      now.add(duration.minutes(new BN("1"))),
      ZERO_ADDRESS,
      ether("0"),
      ether("0"),
      broker,
      brokerBasePercent,
      brokerQuotePercent,
      { from: orderOwner }
    );

    const baseAmounts = [];
    baseAmounts.push(baseLimit.div(new BN("3")));
    baseAmounts.push(baseLimit.sub(baseAmounts[0]));
    for (let i = 0; i < baseAmounts.length; i++) {
      await depositToken(swaps, id, baseToken, baseAmounts[i], accounts[i + 1]);
    }

    const quoteAmounts = [];
    quoteAmounts.push(quoteLimit.div(new BN("5")));
    quoteAmounts.push(quoteLimit.sub(quoteAmounts[0]));
    for (let i = 0; i < quoteAmounts.length; i++) {
      await depositToken(
        swaps,
        id,
        quoteToken,
        quoteAmounts[i],
        accounts[i + 1 + baseAmounts.length]
      );
    }

    const myWishBaseToReceive = baseLimit
      .mul(myWishBasePercent)
      .div(MAX_PERCENT);
    await baseToken
      .balanceOf(myWish)
      .should.eventually.be.bignumber.equal(myWishBaseToReceive);

    const myWishQuoteToReceive = quoteLimit
      .mul(myWishQuotePercent)
      .div(MAX_PERCENT);
    await quoteToken
      .balanceOf(myWish)
      .should.eventually.be.bignumber.equal(myWishQuoteToReceive);

    const brokerBaseToReceive = baseLimit
      .mul(brokerBasePercent)
      .div(MAX_PERCENT);
    await baseToken
      .balanceOf(broker)
      .should.eventually.be.bignumber.equal(brokerBaseToReceive);

    const brokerQuoteToReceive = quoteLimit
      .mul(brokerQuotePercent)
      .div(MAX_PERCENT);
    await quoteToken
      .balanceOf(broker)
      .should.eventually.be.bignumber.equal(brokerQuoteToReceive);

    for (let i = 0; i < baseAmounts.length; i++) {
      const investorQuoteToReceive = baseAmounts[i]
        .mul(quoteLimit.sub(myWishQuoteToReceive).sub(brokerQuoteToReceive))
        .div(baseLimit);

      await quoteToken
        .balanceOf(accounts[i + 1])
        .should.eventually.be.bignumber.closeTo(investorQuoteToReceive, "1");
    }

    for (let i = 0; i < quoteAmounts.length; i++) {
      const investorBaseToReceive = quoteAmounts[i]
        .mul(baseLimit.sub(myWishBaseToReceive).sub(brokerBaseToReceive))
        .div(quoteLimit);

      await baseToken
        .balanceOf(accounts[i + 1 + baseAmounts.length])
        .should.eventually.be.bignumber.closeTo(investorBaseToReceive, "1");
    }
  });
});
