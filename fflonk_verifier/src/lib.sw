// This file contains all the ecc operations
library;

use std::array_conversions::u256::*;
use std::bytes_conversions::u256::*;
use std::bytes::Bytes;
use core::raw_ptr::*;
use core::raw_slice::*;

pub const QF: u256 = 0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD47u256;
pub const Q: u256 = 0x30644E72E131A029B85045B68181585D2833E84879B9709143E1F593F0000001u256;

pub const G1X: u256 = 1;
pub const G1Y: u256 = 2;

pub const G2X1: u256 = 0x1800DEEF121F1E76426A00665E5C4479674322D4F75EDADD46DEBD5CD992F6EDu256;
pub const G2X2: u256 = 0x198E9393920D483A7260BFB731FB5D25F1AA493335A9E71297E485B7AEF312C2u256;
pub const G2Y1: u256 = 0x12C85EA5DB8C6DEB4AAB71808DCB408FE3D1E7690C43D37B4CE6CC0166FA7DAAu256;
pub const G2Y2: u256 = 0x90689D0585FF075EC9E99AD690C3395BC4B313370B38EF355ACDADCD122975Bu256;

// G1
pub struct G1Point {
    pub x: u256,
    pub y: u256,
}

// G2
pub struct G2Point {
    pub x: [u256;2],
    pub y: [u256;2],
}

// scalar
pub struct Scalar {
    pub x: u256,
}


impl G1Point {

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
    pub fn check_point_belongs_to_bn128_curve(p: G1Point) -> bool {

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