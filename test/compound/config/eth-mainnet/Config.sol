// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@contracts/compound/interfaces/compound/ICompound.sol";
import "@contracts/compound/interfaces/IMorpho.sol";
import "@contracts/compound/interfaces/ILens.sol";

import "@rari-capital/solmate/src/tokens/ERC20.sol";

contract Config {
    ERC20 constant aave = ERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    ERC20 constant dai = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ERC20 constant usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 constant usdt = ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    ERC20 constant wbtc = ERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    ERC20 constant weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ERC20 constant comp = ERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    ERC20 constant bat = ERC20(0x0D8775F648430679A709E98d2b0Cb6250d2887EF);
    ERC20 constant tusd = ERC20(0x0000000000085d4780B73119b644AE5ecd22b376);
    ERC20 constant uni = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    ERC20 constant zrx = ERC20(0xE41d2489571d322189246DaFA5ebDe1F4699F498);
    ERC20 constant link = ERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    ERC20 constant mkr = ERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
    ERC20 constant fei = ERC20(0x956F47F50A910163D8BF957Cf5846D573E7f87CA);
    ERC20 constant yfi = ERC20(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    ERC20 constant usdp = ERC20(0x8E870D67F660D95d5be530380D0eC0bd388289E1);
    ERC20 constant sushi = ERC20(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);

    ICToken constant cAave = ICToken(0xe65cdB6479BaC1e22340E4E755fAE7E509EcD06c);
    ICToken constant cDai = ICToken(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    ICToken constant cUsdc = ICToken(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    ICToken constant cUsdt = ICToken(0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9);
    ICToken constant cWbtc = ICToken(0xC11b1268C1A384e55C48c2391d8d480264A3A7F4);
    ICToken constant cEth = ICToken(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    ICToken constant cBat = ICToken(0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E);
    ICToken constant cTusd = ICToken(0x12392F67bdf24faE0AF363c24aC620a2f67DAd86);
    ICToken constant cUni = ICToken(0x35A18000230DA775CAc24873d00Ff85BccdeD550);
    ICToken constant cComp = ICToken(0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4);
    ICToken constant cZrx = ICToken(0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407);
    ICToken constant cLink = ICToken(0xFAce851a4921ce59e912d19329929CE6da6EB0c7);
    ICToken constant cMkr = ICToken(0x95b4eF2869eBD94BEb4eEE400a99824BF5DC325b);
    ICToken constant cFei = ICToken(0x7713DD9Ca933848F6819F38B8352D9A15EA73F67);
    ICToken constant cYfi = ICToken(0x80a2AE356fc9ef4305676f7a3E2Ed04e12C33946);
    ICToken constant cUsdp = ICToken(0x041171993284df560249B57358F931D9eB7b925D);
    ICToken constant cSushi = ICToken(0x4B0181102A0112A2ef11AbEE5563bb4a3176c9d7);

    IMorpho constant morpho = IMorpho(0x8888882f8f843896699869179fB6E4f7e3B58888);
    ILens constant lens = ILens(0xE8CFA2EdBDC110689120724C4828232E473be1B2);

    IComptroller constant comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
}
