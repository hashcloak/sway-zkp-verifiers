// SPDX-License-Identifier: GPL-3.0
/*
Copyright 2021 0KIMS association.

This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

snarkJS is a free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

snarkJS is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
License for more details.

You should have received a copy of the GNU General Public License
along with snarkJS. If not, see
<https: //www.gnu.org/licenses />.
*/

contract;

use std::hash::Hash;
use std::hash::keccak256;
use std::array_conversions::u256::*;
use std::bytes_conversions::u256::*;
use std::bytes::Bytes;

const ZERO: u256 = 0;

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

impl G2Point {

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
}

pub fn on_bn128_curve(p: G1Point) -> bool {

    let mut res: u256 = 0;
    // y^2 mod qf
    asm(rA: res, rB: p.y, rC: p.y, rD: qf) {
        wqmm rA rB rC rD;
    }

    let mut x_square: u256 = 0;
    // x^2 mod qf
    asm(rA: x_square, rB: p.x, rC: p.x, rD: qf) {
        wqmm rA rB rC rD;
    }

    let mut x_cubed: u256 = 0;
    // x^3 mod qf
    asm(rA: x_cubed, rB: x_square, rC: p.x, rD: qf) {
        wqmm rA rB rC rD;
    }

    // x^3 + 3 mod qf
    let mut res_x: u256 = 0;
    asm(rA: res_x, rB: x_cubed, rC: 0x3u256, rD: qf) {
        wqam rA rB rC rD;
    }
    
    res_x == res
}

// Omega
const w1: u256 = 0x2b337de1c8c14f22ec9b9e2f96afef3652627366f8170a0a948dad4ac1bd5e80u256;
// Scalar field size
const q: u256  = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001u256;
// Base field size
const qf: u256 = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47u256;

// [1]_1
const G1x: u256 = 0x1u256;
const G1y: u256 = 0x2u256;
const G1: G1Point = G1Point {x: G1x, y: G1y };
// [1]_2
const G2x1: u256 = 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6edu256;
const G2x2: u256 = 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2u256;
const G2y1: u256 = 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daau256;
const G2y2: u256 = 0x90689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975bu256;

// Verification Key data
const n: u32         = 8;
const nPublic: u16   = 1;
const nLagrange: u16 = 1;

const Qmx: u256  = 0x2c57c027139e6180ffe97afe98302047d9735b7d908ea81560e47bff9e8e22c4u256;
const Qmy: u256  = 0x262083f2a8a93f6b51632108b9d9840857dd75283f84df5b869dc7097e4565du256;
const Qlx: u256  = 0x2ad388fadb2fb24da9e185e8980c34606e894b5bc9ccb869ec6b3ce0581c21c4u256;
const Qly: u256  = 0xa257b67dfeea095a8fc2d6649893105b3f5d94495f14252676a94cf97c6dcdcu256;
const Qrx: u256  = 0x7a719859f6efcc21f54ba91b2a8ca6826d94fcc028022f2a7f915f2097a5e37u256;
const Qry: u256  = 0xdc183f776d67a93099f0b57ab8fd9ee4bcf75d4a29a3dcb7f4d5fd2738b0c51u256;
const Qox: u256  = 0x406177fcc55c227edd0b7133db05cb87d611a1bc46185a9d3bfcf779caa9fb7u256;
const Qoy: u256  = 0x5922093e997a3df08d9359b7234eee1c2265602988d3216244860f7a10fe9feu256;
const Qcx: u256  = 0x0u256;
const Qcy: u256  = 0x0u256;
const S1x: u256  = 0x2700d44e9842cd4d9277c77dca3d4cd371159a10f1c51a57a9d06e7ec4858807u256;
const S1y: u256  = 0x21b6087e43f6cf3530a1c455625b279e5afd568bfc6e96f10c453bc98a803f3du256;
const S2x: u256  = 0xeb2444f19ada5e8a93945592d6852f514b4a44b621f12ca04d0bc780d4c544eu256;
const S2y: u256  = 0x2be6c8b629c37b81a6e7206fb6c68fa180c5a60c1d7461552d1aec1b3085651bu256;
const S3x: u256  = 0x1b932b35e2a675fda27050e30d82fb7400760c74a0b300ffaf7f121fa8e6f72fu256;
const S3y: u256  = 0x1cd8f9f03d8b6b40c897d33c41c4aee90cc7d9c2ba10bd19db1fdf99dbef8906u256;
const k1: u256   = 0x2u256;
const k2: u256   = 0x3u256;
const X2x1: u256 = 0x1174d238e8e0e33844b30c8db7d0d00757014cc24d20fda74348f2a4ab553690u256;
const X2x2: u256 = 0x1a330e16d6559abc41678bfa95d350c7264530a576cb96d5cf1b0810baf4d6d8u256;
const X2y1: u256 = 0x1e98ae1701aa5ceeb7c41cf511bd709999029d48aadfcb003159d1808885ababu256;
const X2y2: u256 = 0x259c37e55c49a1351673a9563f52e8bcb828ce299aae28cb56ccca3dd0ea1616u256;

const Qm: G1Point = G1Point {x: Qmx, y: Qmy };
const Ql: G1Point = G1Point {x: Qlx, y: Qly };
const Qr: G1Point = G1Point {x: Qrx, y: Qry };
const Qo: G1Point = G1Point {x: Qox, y: Qoy };
const Qc: G1Point = G1Point {x: Qcx, y: Qcy };
const S1: G1Point = G1Point {x: S1x, y: S1y };
const S2: G1Point = G1Point {x: S2x, y: S2y };
const S3: G1Point = G1Point {x: S3x, y: S3y };

struct Proof {
  pub proof_A: G1Point,
  pub proof_B: G1Point,
  pub proof_C: G1Point,
  pub proof_Z: G1Point,
  pub proof_T1: G1Point,
  pub proof_T2: G1Point,
  pub proof_T3: G1Point,
  pub proof_Wxi: G1Point,
  pub proof_Wxiw: G1Point,
  pub eval_a: u256,
  pub eval_b: u256,
  pub eval_c: u256,
  pub eval_s1: u256,
  pub eval_s2: u256,
  pub eval_zw: u256,
}

// Functions hardcoded mod q
impl u256 {
  fn addmod(self, other: u256) -> u256 {
      let mut res: u256 = 0;
      asm (rA: res, rB: self, rC: other, rD: q) {
      wqam rA rB rC rD;
      };
      res
  }

  fn mulmod(self, other: u256) -> u256 {
      let mut res: u256 = 0;
      asm (rA: res, rB: self, rC: other, rD: q) {
      wqmm rA rB rC rD;
      }
      res
  }

  fn submod(self, other: u256) -> u256 {
      let mut res: u256 = q - other;
      asm (rA: res, rB: self, rD: q) {
      wqam rA rB rA rD;
      }
      res
  }
}

impl Proof {

  // Computes the inverse using the extended euclidean algorithm
  pub fn inverse(a: u256) -> u256 {
      let mut t = 0;
      let mut newt = 1;
      let mut r = q;
      let mut newr = a;
      let mut quotient = 0;
      let mut aux = 0;
      while newr != 0 {
        quotient = r / newr;
        // aux = t - quotient*newt
        let mut qt = 0;
        asm (rA: qt, rB: quotient, rC: newt, rD: q){
          wqmm rA rB rC rD;
        }
        qt = q - qt;
        asm (rA: aux, rB: t, rC: qt, rD: q){
          wqam rA rB rC rD;
        }
        t = newt;
        newt = aux;
        // aux = r - quotient*newr
        let mut qr = 0;
        asm (rA: qr, rB: quotient, rC: newr, rD:q){
          wqmm rA rB rC rD;
        }
        qr = q - qr;
        asm (rA: aux, rB: r, rC: qr, rD: q){
          wqam rA rB rC rD;
        }
        r = newr;
        newr = aux;
      };
      t
  }
  // Computes the inverse of an array of values
  // Array length n will change based on the input
  fn inverse_array(ref mut vals: [u256; 1]){
      // aux_array length = n-1
      //NOTE - for array length = 1, aux_array will have type [u256;0], 
      // seems like the compiler won't complain about it
      let mut aux_array: [u256; 0] = [0; 0];
      let mut pos = 1;
      let mut acc = vals[0];
      // calculate acc = vals[0]*vals[1]*...*vals[n]
      // pos < vals length
      while pos < 1 {
        aux_array[pos-1] = acc;
        asm (rA: acc, rB: vals[pos], rC:q){
          wqmm rA rA rB rC;
        }
        pos += 1;
      }
      // calculate inverse of acc
      acc = Self::inverse(acc);
      // pos will be pointing at n+1
      pos -= 1;
      // calaulate inverse for every val
      while pos > 0 {
        let inv = 0;
        asm (rA: inv, rB: acc, rC: aux_array[pos-1], rD:q){
          wqmm rA rB rC rD;
        }
        asm (rA: acc, rB: vals[pos], rC:q){
          wqmm rA rA rB rC;
        }
        vals[pos] = inv;
        pos -= 1;
      }
      vals[pos] = acc;
  }

  // beta, gamma, alpha, xi (=zeta), v, u
  fn get_challenges(self, publicInput: [u256; 1]) -> [b256;6] {
      let mut transcript: Bytes = Bytes::new();

      ////// BETA
      transcript.append(Qmx.to_be_bytes());
      transcript.append(Qmy.to_be_bytes());
      transcript.append(Qlx.to_be_bytes());
      transcript.append(Qly.to_be_bytes());
      transcript.append(Qrx.to_be_bytes());
      transcript.append(Qry.to_be_bytes());
      transcript.append(Qox.to_be_bytes());
      transcript.append(Qoy.to_be_bytes());
      transcript.append(Qcx.to_be_bytes());
      transcript.append(Qcy.to_be_bytes());
      transcript.append(S1x.to_be_bytes());
      transcript.append(S1y.to_be_bytes());
      transcript.append(S2x.to_be_bytes());
      transcript.append(S2y.to_be_bytes());
      transcript.append(S3x.to_be_bytes());
      transcript.append(S3y.to_be_bytes());
      // nPublic*32 bytes of public data
      let mut i = 0;
      while i < 1 {
          transcript.append(Bytes::from(publicInput[i].to_be_bytes()));
          i += 1;
      }
      transcript.append(self.proof_A.bytes());
      transcript.append(self.proof_B.bytes());
      transcript.append(self.proof_C.bytes());
      // beta = hash(transcript) mod q
      let beta: b256 = keccak256(transcript);
      asm (rA: beta, rC: ZERO, rD: q) {
          wqam rA rA rC rD;
      };
      
      ////// GAMMA
      // gamma = hash(beta) mod q
      // Note: this follows snarkjs Plonk verifier beta = hash(transcript) and gamma = hash(beta)
      // While the paper does beta = hash(transcript, 0) and gamma=hash(transcript,1))
      let gamma: b256 = keccak256(beta);
      asm (rA: gamma, rC: ZERO, rD: q) {
          wqam rA rA rC rD;
      };
      
      ////// ALPHA
      // alpha = hash(beta, gamma, proof_Z) mod q
      let mut transcript: Bytes = Bytes::new();
      transcript.append(Bytes::from(beta));
      transcript.append(Bytes::from(gamma));
      transcript.append(self.proof_Z.bytes());
      let alpha: b256 = keccak256(transcript);
      asm (rA: alpha, rC: ZERO, rD: q) {
          wqam rA rA rC rD;
      };
      
      ////// XI
      // xi = hash(alpha, proof_T1, proof_T2, proof_T3) mod qs
      let mut transcript: Bytes = Bytes::new();
      transcript.append(Bytes::from(alpha));
      transcript.append(self.proof_T1.bytes());
      transcript.append(self.proof_T2.bytes());
      transcript.append(self.proof_T3.bytes());
      let xi: b256 = keccak256(transcript);
      asm (rA: xi, rC: ZERO, rD: q) {
          wqam rA rA rC rD;
      };

      ////// V
      // v = hash(xi, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw)
      let mut transcript: Bytes = Bytes::new();
      transcript.append(Bytes::from(xi));
      transcript.append(self.eval_a.to_be_bytes());
      transcript.append(self.eval_b.to_be_bytes());
      transcript.append(self.eval_c.to_be_bytes());
      transcript.append(self.eval_s1.to_be_bytes());
      transcript.append(self.eval_s2.to_be_bytes());
      transcript.append(self.eval_zw.to_be_bytes());
      let v: b256 = keccak256(transcript);
      asm (rA: v, rC: ZERO, rD: q) {
          wqam rA rA rC rD;
      };

      ////// U
      // u = hash(wxi, wxiw)
      let mut transcript: Bytes = Bytes::new();
      transcript.append(self.proof_Wxi.bytes());
      transcript.append(self.proof_Wxiw.bytes());
      let u: b256 = keccak256(transcript);
      asm (rA: u, rC: ZERO, rD: q) {
          wqam rA rA rC rD;
      };

      return [beta, gamma, alpha, xi, v, u]
  }

  fn calculateLagrange(self, xi: u256, ref mut pEval: [u256; 1]) -> u256 {
    // We want for i=0..nPublic: Li(z) = ω^i(z^n−1) / n(z−ω^i)

    // 1. pEval_i = n(xi-w^i) mod q
    // 2. then all pEval_i get inverted => 1/ n(xi-w^i)
    // 3. finally multiply the numerator ending up with pEval_i = ω^i(z^n−1) / n(z−ω^i)
    let mut i = 0;
    let mut w = 1;
    // Step 1.
    while i < 1 {
        let temp = xi.submod(w);
        pEval[i] = temp.mulmod(n.as_u256());
        w = w.mulmod(w1);
        i = i + 1;
    }

    // Step 2: invert all entries of pEval
    Proof::inverse_array(pEval);

    // Step 3
    let power = 3;
    i = 0;
    let mut xi_pow_n: u256 = xi;
    while i < power {
        // mem[$rA,32] = (b*c)%d
        asm (rA: xi_pow_n, rB: xi_pow_n, rC: xi_pow_n, rD: q) {
          wqmm rA rB rC rD;
        };

        i = i + 1;
    }
    let num: u256 = xi_pow_n.submod(1);
    i = 0;
    w = 1;
    while i < 1 {
        pEval[i] = w.mulmod(pEval[i]).mulmod(num);
        w = w.mulmod(w1);
        i = i + 1;
    }

    // return xi_pow_n for further usage, pEval has been modified in place
    return xi_pow_n;
  }

  // SUM(w_i*L_i(xi)) 
  fn calculatePI(self, pEval: [u256; 1], publicInput: [u256; 1]) -> u256 {
      let mut res: u256 = 0;
      let mut temp: u256 = 0;
      let mut i = 0;
      while i < nPublic.as_u64() {
        // temp = pEval[i]*publicInput[i] mod q
        asm (rA: temp, rB: pEval[i], rC: publicInput[i], rD: q) {
          wqmm rA rB rC rD;
        };
        // accumulate all values in res
        // res = res + temp
        asm (rA: res, rB: res, rC: temp, rD: q) {
          wqam rA rB rC rD;
        };
        i = i + 1;
      }

      // Same as in Solidity code, negate PI
      return q.submod(res);
  }

  // r0 := PI(z) − L1(z)α2 − α(¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)(¯c + γ)¯zω,
  fn calculateR0(self,
    PIz: u256, 
    pEval_l1: u256,
    alpha: u256,
    alpha_squared: u256,
    beta: u256,
    gamma: u256) -> u256 {
      ///// SECOND TERM
      // L1(z)α2 
      let mut second_term: u256 = 0;
      asm (rA: second_term, rB: pEval_l1, rC: alpha_squared, rD: q) {
        wqmm rA rB rC rD;
      };
      
      ///// THIRD TERM
      // part 1: (¯a + β¯sσ1 + γ)
      
      // Step 1: third_term_1 =  β¯sσ1
      let mut third_term_1: u256 = 0;
      asm (rA: third_term_1, rB: beta, rC: self.eval_s1, rD: q) {
        wqmm rA rB rC rD;
      };
      // Step 2: third_term_1 =  ¯a + β¯sσ1
      asm (rA: third_term_1, rB: self.eval_a, rC: third_term_1, rD: q) {
        wqam rA rB rC rD;
      };
      // Step 3: third_term_1 = ¯a + β¯sσ1 + γ
      asm (rA: third_term_1, rB: third_term_1, rC: gamma, rD: q) {
        wqam rA rB rC rD;
      };

      // part 2: (¯b + β¯sσ2 + γ)
      let mut third_term_2: u256 = 0;
      asm (rA: third_term_2, rB: beta, rC: self.eval_s2, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: third_term_2, rB: self.eval_b, rC: third_term_2, rD: q) {
        wqam rA rB rC rD;
      };
      asm (rA: third_term_2, rB: third_term_2, rC: gamma, rD: q) {
        wqam rA rB rC rD;
      };

      // part 3: (¯c + γ)
      let mut third_term_3: u256 = 0;
      asm (rA: third_term_3, rB: self.eval_c, rC: gamma, rD: q) {
        wqam rA rB rC rD;
      };

      // α(¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)(¯c + γ)¯zω
      let mut temp0: u256 = 0;
      asm (rA: temp0, rB: alpha, rC: third_term_1, rD: q) {
        wqmm rA rB rC rD;
      };
      let mut temp1: u256 = 0;
      asm (rA: temp1, rB: third_term_2, rC: third_term_3, rD: q) {
        wqmm rA rB rC rD;
      };
      let mut third_term: u256 = 0;
      asm (rA: third_term, rB: self.eval_zw, rC: temp0, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: third_term, rB: third_term, rC: temp1, rD: q) {
        wqmm rA rB rC rD;
      };

      // PI(z) − L1(z)α2 − α(¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)(¯c + γ)¯zω
      // PI(z) + (q - L1(z)α2) + (q - α(¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)(¯c + γ)¯zω)

      let mut q_minus_second: u256 = q - second_term;
      let mut q_minus_third: u256 = q - third_term;

      let mut res: u256 = 0;
      asm (rA: res, rB: PIz, rC: q_minus_second, rD: q) {
        wqam rA rB rC rD;
      };
      asm (rA: res, rB: res, rC: q_minus_third, rD: q) {
        wqam rA rB rC rD;
      };
      return res;
  }
  
  fn calculateD(self,
    pEval_l1: u256,
    alpha: u256,
    alpha_squared: u256,
    beta: u256,
    gamma: u256,
    xi: u256, // xi
    xi_pow_n: u256, // xi^n
    v: u256,
    u: u256) -> G1Point {

      //// TERM 1
      let mut point_term_1 = Qc;
      // eval_a*eval_b*Gm
      let mut temp0: u256 = 0;
      asm (rA: temp0, rB: self.eval_a, rC: self.eval_b, rD: q) {
        wqmm rA rB rC rD;
      };
      let temp0_point = Qm.u256_mul(temp0);
      point_term_1 = point_term_1.point_add(temp0_point);
      //eval_a*Ql
      let temp1_point = Ql.u256_mul(self.eval_a);
      point_term_1 = point_term_1.point_add(temp1_point);
      //eval_b*Qr
      let temp2_point = Qr.u256_mul(self.eval_b);
      point_term_1 = point_term_1.point_add(temp2_point);
      //eval_c*Qo
      let temp3_point = Qo.u256_mul(self.eval_c);
      point_term_1 = point_term_1.point_add(temp3_point);

      //// TERM 2
      // (¯a + βz + γ)
      let mut betaxi: u256 = 0;
      asm (rA: betaxi, rB: beta, rC: xi, rD: q) {
        wqmm rA rB rC rD;
      };
      let mut val1: u256 = 0;
      asm (rA: val1, rB: betaxi, rC: self.eval_a, rD: q) {
        wqam rA rB rC rD;
      };
      asm (rA: val1, rB: val1, rC: gamma, rD: q) {
        wqam rA rB rC rD;
      };

      // (¯b + βk1z + γ)
      let mut val2: u256 = 0;
      asm (rA: val2, rB: betaxi, rC: k1, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: val2, rB: val2, rC: self.eval_b, rD: q) {
        wqam rA rB rC rD;
      };
      asm (rA: val2, rB: val2, rC: gamma, rD: q) {
        wqam rA rB rC rD;
      };

      // (¯c + βk2z + γ)
      let mut val3: u256 = 0;
      asm (rA: val3, rB: betaxi, rC: k2, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: val3, rB: val3, rC: self.eval_c, rD: q) {
        wqam rA rB rC rD;
      };
      asm (rA: val3, rB: val3, rC: gamma, rD: q) {
        wqam rA rB rC rD;
      };

      // (¯a + βz + γ)(¯b + βk1z + γ)(¯c + βk2z + γ)α
      let mut d2a: u256 = 0;
      asm (rA: d2a, rB: val1, rC: val2, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: d2a, rB: d2a, rC: val3, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: d2a, rB: d2a, rC: alpha, rD: q) {
        wqmm rA rB rC rD;
      };

      // L1(z)α2
      let mut d3a: u256 = 0;
      asm (rA: d3a, rB: pEval_l1, rC: alpha_squared, rD: q) {
        wqmm rA rB rC rD;
      };

      // (¯a + βz + γ)(¯b + βk1z + γ)(¯c + βk2z + γ)α + L1(z)α2 + u
      let mut u256_term_2: u256 = 0;
      asm (rA: u256_term_2, rB: d2a, rC: d3a, rD: q) {
        wqam rA rB rC rD;
      };
      asm (rA: u256_term_2, rB: u256_term_2, rC: u, rD: q) {
        wqam rA rB rC rD;
      };

      // ((¯a + βz + γ)(¯b + βk1z + γ)(¯c + βk2z + γ)α + L1(z)α2 + u) · [z]1
      let point_term2 = self.proof_Z.u256_mul(u256_term_2);

      //// TERM 3
      // (¯a + β¯sσ1 + γ)
      asm (rA: val1, rB: beta, rC: self.eval_s1, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: val1, rB: val1, rC: self.eval_a, rD: q) {
        wqam rA rB rC rD;
      };
      asm (rA: val1, rB: val1, rC: gamma, rD: q) {
        wqam rA rB rC rD;
      };

      // (¯b + β¯sσ2 + γ)
      asm (rA: val2, rB: beta, rC: self.eval_s2, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: val2, rB: val2, rC: self.eval_b, rD: q) {
        wqam rA rB rC rD;
      };
      asm (rA: val2, rB: val2, rC: gamma, rD: q) {
        wqam rA rB rC rD;
      };

      // αβ¯zω
      asm (rA: val3, rB: alpha, rC: beta, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: val3, rB: val3, rC: self.eval_zw, rD: q) {
        wqmm rA rB rC rD;
      };

      // (¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)αβ¯zω
      let mut u256_term3: u256 = 0;
      asm (rA: u256_term3, rB: val1, rC: val2, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: u256_term3, rB: u256_term3, rC: val3, rD: q) {
        wqmm rA rB rC rD;
      };

      // (¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)αβ¯zω · [sσ3]1
      let point_term3 = S3.u256_mul(u256_term3);

      //// TERM 4
      let mut point_term4: G1Point = self.proof_T1;
      // xi^n[t_mid]1
      let mut temp_point: G1Point = self.proof_T2.u256_mul(xi_pow_n);
      point_term4 = point_term4.point_add(temp_point);
      
      // xi^2n
      asm (rA: val2, rB: xi_pow_n, rC: xi_pow_n, rD: q) {
        wqmm rA rB rC rD;
      };
      // xi^2n · [t_hi]1
      temp_point = self.proof_T3.u256_mul(val2);
      point_term4 = point_term4.point_add(temp_point);

      // ZH(z)([tlo]1 + zn · [tmid]1 + z2n · [thi]1)
      point_term4 = point_term4.u256_mul(xi_pow_n - 1);

      // negate point term3
      let neg_y_3: u256 = qf - point_term3.y;
      let neg_term3 = G1Point{
          x: point_term3.x,
          y: neg_y_3
      };
      let mut neg_y_bytes: [u8; 64] = neg_term3.to_bytes();

      // negate point term4
      let neg_y_4 = qf - point_term4.y;
      let neg_term4 = G1Point{
          x: point_term4.x,
          y: neg_y_4
      };
      let mut res: G1Point = point_term_1.point_add(point_term2);
      res = res.point_add(neg_term3);
      res = res.point_add(neg_term4);
      return res;
  }

  fn calculateF(self,
    v: u256,
    v2: u256,
    v3: u256,
    v4: u256,
    v5: u256,
    D: G1Point
  ) -> G1Point {
      // D + v · [a]1
      let mut temp: G1Point = self.proof_A.u256_mul(v);
      let mut res: G1Point = D.point_add(temp);
      // v2 · [b]1
      temp = self.proof_B.u256_mul(v2);
      res = res.point_add(temp);
      // v3 · [c]1
      temp = self.proof_C.u256_mul(v3);
      res = res.point_add(temp);
      // v4 · [sσ1]1
      temp = S1.u256_mul(v4);
      res = res.point_add(temp);
      // v5 · [sσ2]1
      temp = S2.u256_mul(v5);
      res = res.point_add(temp);
      return res; 
  }

  fn calculateE(self,
    r0: u256,
    u: u256,
    v: u256,
    v2: u256,
    v3: u256,
    v4: u256,
    v5: u256,
    ) -> G1Point {
      // −r0 + v¯a + v2¯b + v3¯c + v4¯sσ1 + v5¯sσ2 + u¯zω
      // q-r0
      let mut acc_u256: u256 = q - r0;
      let mut temp: u256 = 0;
      asm (rA: temp, rB: v, rC: self.eval_a, rD: q) {
        wqmm rA rB rC rD;
      };
      acc_u256 += temp;
      asm (rA: temp, rB: v2, rC: self.eval_b, rD: q) {
        wqmm rA rB rC rD;
      };
      acc_u256 += temp;
      asm (rA: temp, rB: v3, rC: self.eval_c, rD: q) {
        wqmm rA rB rC rD;
      };
      acc_u256 += temp;
      asm (rA: temp, rB: v4, rC: self.eval_s1, rD: q) {
        wqmm rA rB rC rD;
      };
      acc_u256 += temp;
      asm (rA: temp, rB: v5, rC: self.eval_s2, rD: q) {
        wqmm rA rB rC rD;
      };
      acc_u256 += temp;
      asm (rA: temp, rB: u, rC: self.eval_zw, rD: q) {
        wqmm rA rB rC rD;
      };
      acc_u256 += temp;
      let res = G1.u256_mul(acc_u256);
      return res; 
  }


  // In this case, public input has length 1
  pub fn verify(self, publicInput: [u256; 1]) -> bool {
      // 1. Check points are on curve
      // ([a]1, [b]1, [c]1, [z]1, [tlo]1, [tmid]1, [thi]1, [Wz]1, [Wzω]1) ∈ G91
      if !(on_bn128_curve(self.proof_A)
          && on_bn128_curve(self.proof_B)
          && on_bn128_curve(self.proof_C)
          && on_bn128_curve(self.proof_Z)
          && on_bn128_curve(self.proof_T1)
          && on_bn128_curve(self.proof_T2)
          && on_bn128_curve(self.proof_T3)
          && on_bn128_curve(self.proof_Wxi)
          && on_bn128_curve(self.proof_Wxiw)) {
          return false;
      }
      // 2. Validate (¯a, ¯b, ¯c,¯sσ1,¯sσ2, ¯zω) ∈ F6 (u256 field, q)
      if !(self.eval_a < q
          && self.eval_b < q
          && self.eval_c < q
          && self.eval_s1 < q
          && self.eval_s2 < q
          && self.eval_zw < q) {
        return false; 
      }
      // 3. Validate public input 
      // (wi)i∈[ℓ] ∈ Fℓ
      let mut i = 0;
      while i < 1 {
          if publicInput[i] >= q {
            return false; 
          }
          i += 1;
      }
      
      // Step 4: Recompute challenges beta, gamma, alpha, xi, v, and u in the field F
      // (β, γ, α, z, v, u)
      let challenges = self.get_challenges(publicInput);
      let beta = u256::from(challenges[0]);
      let gamma = u256::from(challenges[1]);
      let alpha = u256::from(challenges[2]);
      let xi = u256::from(challenges[3]);
      let v = u256::from(challenges[4]);
      let u = u256::from(challenges[5]);

      // Step 5&6: compute w(z^n-1)/n*(z-w)
      let mut pEval: [u256; 1] = [0;1];
      let xi_pow_n = self.calculateLagrange(xi, pEval);

      // Step 7: compute PI (public input polynomial evaluation)
      // sum(w_i*L_i(xi)) 
      // Following Solidity implementation -sum(w_i*L_i(xi))
      let PI = self.calculatePI(pEval, publicInput);

      // Step 8: compute R0
      let mut alpha_squared: u256 = 0;
      // mem[$rA,32] = (b*c)%d
      asm (rA: alpha_squared, rB: alpha, rC: alpha, rD: q) {
        wqmm rA rB rC rD;
      };
      let R0 = self.calculateR0(
        PI, 
        pEval[0],
        alpha,
        alpha_squared,
        beta,
        gamma
      );
      
      // Step 9: compute D
      let D = self.calculateD(
        pEval[0],
        alpha,
        alpha_squared,
        beta,
        gamma,
        xi,
        xi_pow_n,
        v,
        u
      );

      // Step 10: compute F
      let mut v2: u256 = 0;
      let mut v3: u256 = 0;
      let mut v4: u256 = 0;
      let mut v5: u256 = 0;
      asm (rA: v2, rB: v, rC: v, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: v3, rB: v2, rC: v, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: v4, rB: v3, rC: v, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: v5, rB: v4, rC: v, rD: q) {
        wqmm rA rB rC rD;
      };
      let F: G1Point = self.calculateF(v, v2, v3, v4, v5, D);

      // Step 11: compute E
      let E: G1Point = self.calculateE(R0, u, v, v2, v3, v4, v5);

      // Step 12: check pairing
      // A1 = [Wz]1 + u · [Wzω]1
      let mut a1: G1Point = self.proof_Wxiw.u256_mul(u);
      a1 = a1.point_add(self.proof_Wxi);
      let a1_neg = G1Point {
        x: a1.x,
        y: (qf - a1.y) % qf
      };

      // B1 = z · [Wz]1 + uzω · [Wzω]1 + [F]1 − [E]1
      let mut b1: G1Point = self.proof_Wxi.u256_mul(xi);
      let mut temp: u256 = 0;
      asm (rA: temp, rB: u, rC: xi, rD: q) {
        wqmm rA rB rC rD;
      };
      asm (rA: temp, rB: temp, rC: w1, rD: q) {
        wqmm rA rB rC rD;
      };

      b1 = b1.point_add(self.proof_Wxiw.u256_mul(temp));
      b1 = b1.point_add(F);
      let E_neg = G1Point {
          x: E.x,
          y: (qf - E.y) % qf
      };
      b1 = b1.point_add(E_neg);

      // Serialize inputs for EPAR
      let mut pairing_input: [u256; 12] = [0; 12];

      // Pairing input: -A1, X2
      pairing_input[0] = a1_neg.x;
      pairing_input[1] = a1_neg.y;
      // g2: [[x1, x0], [y1, y0]]
      pairing_input[3] = X2x1;
      pairing_input[2] = X2x2;
      pairing_input[5] = X2y1;
      pairing_input[4] = X2y2;

      // Pairing input: B1, [1]_2
      pairing_input[6] = b1.x;
      pairing_input[7] = b1.y;
      // g2: [[x1, x0], [y1, y0]]
      pairing_input[9] = G2x1;
      pairing_input[8] = G2x2;
      pairing_input[11] = G2y1;
      pairing_input[10] = G2y2;

      // Perform pairing check
      let curve_id: u32 = 0;
      let groups_of_points: u32 = 2;
      
      let result: u32 = asm(rA, rB: curve_id, rC: groups_of_points, rD: pairing_input) {
          epar rA rB rC rD;
          rA: u32
      };
      
      result != 0
  }
}

fn get_test_proof() -> Proof {
    let proof_A = G1Point{
      x: 0x18df2709aa980183797c047a54116082a96f34e527dcf62889cf6bb4eef84e5cu256,
      y: 0x04fba0060dde1c12bf17f3bc084e1a3c0c88d4788c175b940af0dce851269a8du256
    };
    let proof_B = G1Point{
      x: 0x2b98022ac7b1fad319fee7084835c9a9b7582ef7c8d943ed020e07b3c54c10d3u256,
      y: 0x058f1292f9d8ba879bd31d2aa58ffdc55e6712856365303ad74c27897c3b1abfu256
    };
    let proof_C = G1Point{
      x: 0x1373a25910655a772add48e50d37577ab3ea63ee6ae10e3f213147cbb90de253u256,
      y: 0x15054e62e1222a289aa1e43d25448db16ac4d9db6888658696b7d938c28bf0f5u256
    };
    let proof_Z = G1Point{
      x: 0x19744b59b68020722eee63bb6300fc6a1e073893ab0362bfb57be09ab6664906u256,
      y: 0x146d6a9652da16d4f7d348b0e5d04917fa24e2d8dbc661edd119c1e916a65ab0u256
    };
    let proof_T1 = G1Point{
      x: 0x17d8c8e3ba3ceea69ffb346b1d485d643736a803b8c37fa533bfc52426c4357bu256,
      y: 0x281db4d7a687889403f00e25610fbea918258441046af9734700e325b084a516u256
    };
    let proof_T2 = G1Point{
      x: 0x21176006386d7c93b2f484e6c1bb9a6e4a2f7c484847842e149954a1cb4368a3u256,
      y: 0x10cec116383a899b35407d232bec3a34a90e6181d4967eb87f669b852bc77fddu256
    };
    let proof_T3 = G1Point{
      x: 0x2396b7ef591449f895a0f015447d85e5a739cee641e2f2be670984870736a1a1u256,
      y: 0x1ea8373ecd71bf25cb4379ca25ab4b2a204b9a6f091eaecc0dd0cf70061e1c19u256
    };
    let proof_Wxi = G1Point{
      x: 0x03d25aff8a329d7fa42ebd49ec5873284770b2713ef2c261ec8d0cb53997e554u256,
      y: 0x02236a075a9b3a242b9ce8cc8df0856878f9882dfa6908ca5d81ee840ab805d8u256
    };
    let proof_Wxiw = G1Point{
      x: 0x1683e98e6836e696420ae4f12787515d2332a91b21f4b7dcba1896585b1b3c05u256,
      y: 0x0556d096582c84fb5a8eb7e604889d9fcac51251b43cb5907d9336d0f9a90963u256
    };

    // Scalar values
    let eval_a = 0x242b5bf8b080116f0ba14c6d897c96dad80e16bbbd6e8e377ba7f04b3ec0ef13u256;
    let eval_b = 0x2517ee116e48c18d2b7ab62577247d532a6e008f712de1fd0a986cac02776664u256;
    let eval_c = 0x05b3a9a111a48a77c1877fc4849a1c615d397c887ba522ee96935c467d02c6e7u256;
    let eval_s1 = 0x2a9847066b3a866ce2db242b61ba6b6499b8e51329a66c8a73412e4faf61f601u256;
    let eval_s2 = 0x121a59004796eeb62e8dec1f043b5f6420e09d4aefc4fc9a89e494600fab5db3u256;
    let eval_zw = 0x0e02f82d37c85532f71188fdfc54a6ace4d0fc122de6b07fe7802d3a432ac9f7u256;

    let proof = Proof {
      proof_A: proof_A,
      proof_B: proof_B,
      proof_C: proof_C,
      proof_Z: proof_Z,
      proof_T1: proof_T1,
      proof_T2: proof_T2,
      proof_T3: proof_T3,
      proof_Wxi: proof_Wxi,
      proof_Wxiw: proof_Wxiw,
      eval_a: eval_a,
      eval_b: eval_b,
      eval_c: eval_c,
      eval_s1: eval_s1,
      eval_s2: eval_s2,
      eval_zw: eval_zw,
    };

    return proof;
  }

  #[test]
  fn test_verification() {
      let proof = get_test_proof();
      let publicInput: [u256; 1] = [0x0000000000000000000000000000000000000000000000000000000000000000u256];
      assert(proof.verify(publicInput));
  }