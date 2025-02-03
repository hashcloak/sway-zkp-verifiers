library;

use std::array_conversions::u256::*;
use std::bytes_conversions::u256::*;
use std::bytes::Bytes;
use std::bytes_conversions::u256::*;
use core::raw_ptr::*;
use core::raw_slice::*;

// Code from https://github.com/man2706kum/sway_ecc

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

impl Scalar {
    pub fn bytes(self) -> Bytes {
      let mut res: Bytes = Bytes::new();
      res.append(Bytes::from(self.x.to_be_bytes()));
      return res;
    }
}

impl G2Point {
    pub fn new() -> G2Point {
        G2Point { x: [0, 0], y: [0, 0] }
    }

    pub fn bytes(self) -> Bytes {
      let mut res: Bytes = Bytes::new();
      res.append(Bytes::from(self.x[0].to_be_bytes()));
      res.append(Bytes::from(self.x[1].to_be_bytes()));
      res.append(Bytes::from(self.y[0].to_be_bytes()));
      res.append(Bytes::from(self.y[1].to_be_bytes()));
      return res;
    }

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
    pub fn new() -> G1Point {
        G1Point { x: 0, y: 0 }
    }

    pub fn bytes(self) -> Bytes {
      let mut res: Bytes = Bytes::new();
      res.append(Bytes::from(self.x.to_be_bytes()));
      res.append(Bytes::from(self.y.to_be_bytes()));
      return res;
    }

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

    pub fn point_add(self, p2: G1Point) -> G1Point {
        let mut input: [u8; 128] = [0; 128];
        let mut output: [u8; 64] = [0; 64];

        let mut p1_bytes: [u8; 64] = self.to_bytes();
        let mut p2_bytes: [u8; 64] = p2.to_bytes();

        let mut i = 0;
        while i < 64 {
            input[i] = p1_bytes[i];
            input[i + 64] = p2_bytes[i];
            i += 1;
        }

        let curve_id: u32 = 0;
        let op_type: u32 = 0;//point addition

        // ecc addition opcode
        // https://github.com/FuelLabs/fuel-specs/blob/abfd0bb29fab605e0e067165363581232c40e0bb/src/fuel-vm/instruction-set.md#ecop-elliptic-curve-point-operation
        asm(rA: output, rB: curve_id, rC: op_type, rD: input) {
            ecop rA rB rC rD;
        }
        
        G1Point::from_bytes(output)
    }

    pub fn scalar_mul(self, s: Scalar) -> G1Point {
        let mut input: [u8; 96] = [0; 96];
        let mut output: [u8; 64] = [0; 64];

        let mut p_bytes: [u8; 64] = self.to_bytes();
        let mut s_bytes: [u8; 32] = s.x.to_be_bytes();

        // preparing inputs
        let mut i = 0;
        while i < 64 {
            input[i] = p_bytes[i];
            i += 1;
        }

        while i < 96 {
            input[i] = s_bytes[i - 64];
            i += 1;
        }

        let curve_id: u32 = 0;
        let op_type: u32 = 1;

        // ecc multiplication opcode
        // https://github.com/FuelLabs/fuel-specs/blob/abfd0bb29fab605e0e067165363581232c40e0bb/src/fuel-vm/instruction-set.md#ecop-elliptic-curve-point-operation
        asm(rA: output, rB: curve_id, rC: op_type, rD: input) {
            ecop rA rB rC rD;
        }

        G1Point::from_bytes(output)
    }


    pub fn u256_mul(self, s: u256) -> G1Point {
        let mut input: [u8; 96] = [0; 96];
        let mut output: [u8; 64] = [0; 64];

        let mut p_bytes: [u8; 64] = self.to_bytes();
        let mut s_bytes: [u8; 32] = s.to_be_bytes();

        // preparing inputs
        let mut i = 0;
        while i < 64 {
            input[i] = p_bytes[i];
            i += 1;
        }

        while i < 96 {
            input[i] = s_bytes[i - 64];
            i += 1;
        }

        let curve_id: u32 = 0;
        let op_type: u32 = 1;

        // ecc multiplication opcode
        // https://github.com/FuelLabs/fuel-specs/blob/abfd0bb29fab605e0e067165363581232c40e0bb/src/fuel-vm/instruction-set.md#ecop-elliptic-curve-point-operation
        asm(rA: output, rB: curve_id, rC: op_type, rD: input) {
            ecop rA rB rC rD;
        }

        G1Point::from_bytes(output)
    }

    // https://github.com/FuelLabs/fuel-specs/blob/abfd0bb29fab605e0e067165363581232c40e0bb/src/fuel-vm/instruction-set.md#epar-elliptic-curve-point-pairing-check
    // checks e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    pub fn pairing(p_g1: G1Point, p_g2: G2Point) -> u32 {
        
        let mut input: [u8; 192] = [0; 192];

        let mut p1_bytes: [u8; 64] = p_g1.to_bytes();
        let mut p2_bytes: [u8; 128] = p_g2.to_bytes();

        let mut i = 0;
        while i < 64 {
            input[i] = p1_bytes[i];
            i += 1;
        }

        while i < 192 {
            input[i] = p2_bytes[i - 64];
            i += 1;
        }

        let curve_id: u32 = 0;
        let groups_of_points: u32 = 1;

        asm(rA, rB: curve_id, rC: groups_of_points, rD: input) {
            epar rA rB rC rD;
            rA: u32
        }
    }
}

pub fn on_bn128_curve(p: G1Point) -> bool {

    let QF: u256 = 0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD47u256;

    let mut res: u256 = 0;
    // y^2 mod QF
    asm(rA: res, rB: p.y, rC: p.y, rD: QF) {
        wqmm rA rB rC rD;
    }

    let mut x_square: u256 = 0;
    // x^2 mod QF
    asm(rA: x_square, rB: p.x, rC: p.x, rD: QF) {
        wqmm rA rB rC rD;
    }

    let mut x_cubed: u256 = 0;
    // x^3 mod QF
    asm(rA: x_cubed, rB: x_square, rC: p.x, rD: QF) {
        wqmm rA rB rC rD;
    }

    // x^3 + 3 mod QF
    let mut res_x: u256 = 0;
    asm(rA: res_x, rB: x_cubed, rC: 0x3u256, rD: QF) {
        wqam rA rB rC rD;
    }
    
    res_x == res
}

