// This file contains all the ecc operations
library;

use std::array_conversions::u256::*;
use std::bytes_conversions::u256::*;
use std::bytes::Bytes;
use core::raw_ptr::*;
use core::raw_slice::*;

pub const QF: u256 = 0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD47u256;

// G1
struct G1Point {
    pub x: u256,
    pub y: u256,
}

// G2
struct G2Point {
    pub x: [u256;2],
    pub y: [u256;2],
}

// scalar
struct Scalar {
    pub x: u256,
}

impl G2Point {
    // creates a new G2Point with all components set to 0
    pub fn new() -> G2Point {
        G2Point { x: [0, 0], y: [0, 0] }
    }

    // converts a G2Point to bytes in big-endian order
    pub fn to_bytes(self) -> [u8; 128] {
        let x0_bytes: [u8; 32] = self.x[0].to_be_bytes();
        let x1_bytes: [u8; 32] = self.x[1].to_be_bytes();
        let y0_bytes: [u8; 32] = self.y[0].to_be_bytes();
        let y1_bytes: [u8; 32] = self.y[1].to_be_bytes();

        let mut result_bytes: [u8; 128] = [0; 128];

        let mut i = 0;
        while i < 32 {
            result_bytes[i] = x0_bytes[i];
            result_bytes[i + 32] = x1_bytes[i];
            result_bytes[i + 64] = y0_bytes[i];
            result_bytes[i + 96] = y1_bytes[i];
            i += 1;
        }

        result_bytes
    }
}

impl G1Point {
    // creates a new G1Point with all components set to 0
    pub fn new() -> G1Point {
        G1Point { x: 0, y: 0 }
    }

    // converts a G1Point to bytes in big-endian order
    pub fn to_bytes(self) -> [u8; 64] {
        let mut x_bytes: [u8; 32] = self.x.to_be_bytes();
        let y_bytes: [u8; 32] = self.y.to_be_bytes();

        let mut result_bytes: [u8; 64] = [0; 64];

        let mut i = 0;
        while i < 32 {
            result_bytes[i] = x_bytes[i];
            result_bytes[i + 32] = y_bytes[i];

            i += 1;
        }

        result_bytes
    }

    // converts bytes in big-endian order to a G1Point
    // the function assumes that the bytes are in big-endian order and the point is a valid point on the curve
    // The reponsibility of checking if the point is valid lies with the caller
    pub fn from_bytes(bytes: [u8; 64]) -> G1Point {

        let mut x_bytes: [u8; 32] = [0; 32];
        let mut y_bytes: [u8; 32] = [0; 32];

        let mut i = 0;
        while i < 32 {
            x_bytes[i] = bytes[i];
            y_bytes[i] = bytes[i + 32];
            i += 1;
        }

        G1Point {
            x: u256::from_be_bytes(x_bytes),
            y: u256::from_be_bytes(y_bytes),
        }
    }

    // https://github.com/FuelLabs/fuel-specs/blob/abfd0bb29fab605e0e067165363581232c40e0bb/src/fuel-vm/instruction-set.md#ecop-elliptic-curve-point-operation
    pub fn point_add(p1: G1Point, p2: G1Point) -> G1Point {
        let mut input: [u256; 4] = [0; 4];
        let mut output: [u256; 2] = [0; 2];

        // prepare input
        input[0] = p1.x;
        input[1] = p1.y;
        input[2] = p2.x;
        input[3] = p2.y;

        // ecc addition opcode
        asm(rA: output, rB: 0, rC: 0, rD: input) {
            ecop rA rB rC rD;
        }
        
        G1Point{
            x: output[0],
            y: output[1],
        }
    }

    // https://github.com/FuelLabs/fuel-specs/blob/abfd0bb29fab605e0e067165363581232c40e0bb/src/fuel-vm/instruction-set.md#ecop-elliptic-curve-point-operation
    pub fn scalar_mul(p: G1Point, s: Scalar) -> G1Point {
        let mut input: [u256; 3] = [0; 3];
        let mut output: [u256; 2] = [0; 2];

        // prepare input
        input[0] = p.x;
        input[1] = p.y;
        input[2] = s.x;

        // ecc multiplication opcode
        asm(rA: output, rB: 0, rC: 1, rD: input) {
            ecop rA rB rC rD;
        }

        G1Point{
            x: output[0],
            y: output[1],
        }
    }

    // https://github.com/FuelLabs/fuel-specs/blob/abfd0bb29fab605e0e067165363581232c40e0bb/src/fuel-vm/instruction-set.md#epar-elliptic-curve-point-pairing-check
    // checks e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    // NOTE: pay attention to encoding of G2 [x0, x1], [y0, y1]
    pub fn pairing(p_g1: G1Point, p_g2: G2Point) -> u32 {
        
        let mut input: [u256; 6] = [0; 6];

        // prepare input
        input[0] = p_g1.x;
        input[1] = p_g1.y;
        input[2] = p_g2.x[0];
        input[3] = p_g2.x[1];
        input[4] = p_g2.y[0];
        input[5] = p_g2.y[1];


        let groups_of_points: u32 = 1;

        asm(rA, rB: 0, rC: groups_of_points, rD: input) {
            epar rA rB rC rD;
            rA: u32
        }
    }

    // Check that the point is on the curve
    // y^2 = x^3 + 3
    fn check_point_belongs_to_bn128_curve(p: G1Point) -> bool {

        let mut res: u256 = 0;
        // y^2 mod QF
        asm(rA: res, rB: p.y, rC: p.y, rD: QF) {
            wqmm rA rB rC rD;
        }
        
        // x^3 + 3 mod QF
        let mut res_x: u256 = 0;
        asm(rA: res_x, rB: p.x, rC: p.x, rD: QF, rE: 0x3u256) {
            wqmm rA rB rC rD;
            wqmm rA rA rB rD;
            wqam rA rA rE rD;
        }

        // check if y^2 == x^3 + 3 mod QF
        res_x == res
    }
}


// from rust arkworks
// g1: (1, 2)
// g2: (QuadExtField(10857046999023057135944570762232829481370756359578518086990519993285655852781 + 11559732032986387107991004021392285783925812861821192530917403151452391805634 * u), QuadExtField(8495653923123431417604973247489272438418190587263600148770280649306958101930 + 4082367875863433681332203403145435568316851327593401208105741076214120093531 * u))
// sum: (1368015179489954701390400359078579693043519447331113978918064868415326638035, 9918110051302171585080402603319702774565515993150576347155970296011118125764)
// scalar_mul: (4444740815889402603535294170722302758225367627362056425101568584910268024244, 10537263096529483164618820017164668921386457028564663708352735080900270541420)
// pairing: QuadExtField(CubicExtField(QuadExtField(17264119758069723980713015158403419364912226240334615592005620718956030922389 + 1300711225518851207585954685848229181392358478699795190245709208408267917898 * u), QuadExtField(8894217292938489450175280157304813535227569267786222825147475294561798790624 + 1829859855596098509359522796979920150769875799037311140071969971193843357227 * u), QuadExtField(4968700049505451466697923764727215585075098085662966862137174841375779106779 + 12814315002058128940449527172080950701976819591738376253772993495204862218736 * u)) + CubicExtField(QuadExtField(4233474252585134102088637248223601499779641130562251948384759786370563844606 + 9420544134055737381096389798327244442442230840902787283326002357297404128074 * u), QuadExtField(13457906610892676317612909831857663099224588803620954529514857102808143524905 + 5122435115068592725432309312491733755581898052459744089947319066829791570839 * u), QuadExtField(8891987925005301465158626530377582234132838601606565363865129986128301774627 + 440796048150724096437130979851431985500142692666486515369083499585648077975 * u)) * u)

#[test]
fn test_add() {
    let g1 = G1Point{
        x: 1,
        y: 2
    };

    let result = G1Point::point_add(g1, g1);
    assert(result.x == 0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD3u256);
    assert(result.y == 0x15ED738C0E0A7C92E7845F96B2AE9C0A68A6A449E3538FC7FF3EBF7A5A18A2C4u256);
}

#[test]
fn test_scalar_mul() {
    let g1 = G1Point{
        x: 1,
        y: 2
    };

    let result = G1Point::scalar_mul(g1, Scalar{ x: 10 });
    assert(result.x == 0x9D3A257B99F1AD804A9E2354EA71C72DA7FA518F4CA7904C6951D924B4045B4u256);
    assert(result.y == 0x174BE12AE3FD899D55D3E487FA103F951A24CA0F670ECAE802209B2518CCCA6Cu256);
}

#[test]
fn test_pairing() {
    let g1 = G1Point{
        x: 1,
        y: 2
    };

    // NOTE: look at the encoding for G2
    // arkworks: g2:{[x0,x1], [y0,y1]} (QuadExtField(10857046999023057135944570762232829481370756359578518086990519993285655852781 + 11559732032986387107991004021392285783925812861821192530917403151452391805634 * u), QuadExtField(8495653923123431417604973247489272438418190587263600148770280649306958101930 + 4082367875863433681332203403145435568316851327593401208105741076214120093531 * u))
    // here: g2: [[x1, x0], [y1, y0]]
    // cross verify for other pairing such that e(g1, g2) == 1

    let g2 = G2Point{
        x: [0x198E9393920D483A7260BFB731FB5D25F1AA493335A9E71297E485B7AEF312C2u256, 0x1800DEEF121F1E76426A00665E5C4479674322D4F75EDADD46DEBD5CD992F6EDu256],
        y: [0x90689D0585FF075EC9E99AD690C3395BC4B313370B38EF355ACDADCD122975Bu256, 0x12C85EA5DB8C6DEB4AAB71808DCB408FE3D1E7690C43D37B4CE6CC0166FA7DAAu256]
    };

    let result = G1Point::pairing(g1, g2);
    assert(result != 1);
}

#[test]
fn test_check_point_belongs_to_bn128_curve() {
    let p = G1Point{
        x: 0x9D3A257B99F1AD804A9E2354EA71C72DA7FA518F4CA7904C6951D924B4045B4u256,
        y: 0x174BE12AE3FD899D55D3E487FA103F951A24CA0F670ECAE802209B2518CCCA6Cu256
    };
    let res = G1Point::check_point_belongs_to_bn128_curve(p);
    assert(res == true);
}