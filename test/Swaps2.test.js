const {
  balance,
  BN,
  constants: {ZERO_ADDRESS},
  ether,
  expectEvent,
  shouldFail,
  time,
  time: {duration}
} = require("openzeppelin-test-helpers");

const {expect} = require("chai");

const Vault = artifacts.require("Vault");
const Swaps = artifacts.require("Swaps");
const Token = artifacts.require("TestToken");
const BNB = artifacts.require("BNB");

contract("Swaps2", ([owner, ...accounts]) => {
  let now;
  let swaps;
  let vault;
  let baseToken;
  let quoteToken;
  let baseLimit = ether('1');
  let quoteLimit = ether('2');

  function getOrderId({logs}) {
    for (let i = 0; i < logs.length; i++) {
      if (logs[i].event === 'OrderCreated') {
        return logs[i].args.id;
      }
    }

    return '';
  }

  async function depositToken(swaps, id, token, amount, from) {
    await token.mint(from, amount);
    await token.approve(swaps.address, amount, {from});
    await swaps.deposit(id, token.address, amount, {from});
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

  it('create simple order', async () => {
    const id = await swaps.createKey(accounts[0]);

    console.info(id);

    await swaps.createOrder(
      id,
      baseToken.address,
      quoteToken.address,
      baseLimit,
      quoteLimit,
      now.add(duration.minutes('1')),
      ZERO_ADDRESS,
      ether('0'),
      ether('0'),
      { from: accounts[0] }
    );
  });

  it('create simple order', async () => {
    const id = await swaps.createKey(accounts[0]);

    await swaps.createOrder(
      id,
      baseToken.address,
      quoteToken.address,
      baseLimit,
      quoteLimit,
      now.add(duration.minutes('1')),
      ZERO_ADDRESS,
      ether('0'),
      ether('0'),
      { from: accounts[0] }
    );

    console.info(id);

    await depositToken(swaps, id, baseToken, ether('1'), accounts[1]);
    await depositToken(swaps, id, quoteToken, ether('2'), accounts[2]);
  });
});
