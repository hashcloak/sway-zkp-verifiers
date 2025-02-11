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

    pub fn point_add(self, other: G1Point) -> Self {
        let mut input: [u256; 4] = [0; 4];
        let mut output: [u256; 2] = [0; 2];

        // prepare input
        input[0] = self.x;
        input[1] = self.y;
        input[2] = other.x;
        input[3] = other.y;

        // ecc addition opcode
        asm(rA: output, rB: 0, rC: 0, rD: input) {
            ecop rA rB rC rD;
        }
        
        G1Point{
            x: output[0],
            y: output[1],
        }
    }

    pub fn u256_mul(self, s: u256) -> Self {
        let mut input: [u256; 3] = [0; 3];
        let mut output: [u256; 2] = [0; 2];

        // prepare input
        input[0] = self.x;
        input[1] = self.y;
        input[2] = s;

        // ecc multiplication opcode
        asm(rA: output, rB: 0, rC: 1, rD: input) {
            ecop rA rB rC rD;
        }

        G1Point{
            x: output[0],
            y: output[1],
        }
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
const w1: u256 = 0x27a358499c5042bb4027fd7a5355d71b8c12c177494f0cad00a58f9769a2ee2u256;
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
const n: u32         = 2048;
const nPublic: u16   = 1;
const nLagrange: u16 = 1;

const Qmx: u256  = 0x257a39d7a5bddadfbabe8ebd7df4c3521a1dbdd8cbbe6332cd609c8612a2ba29u256;
const Qmy: u256  = 0xbaa231049c9662e040924014e3558475d2b6b4c5da421bfbb618dc863697bc8u256;
const Qlx: u256  = 0xa2b203e18cac0013e11d51531fdc50be9787f3ead6af16167163cf546d60aaeu256;
const Qly: u256  = 0x70fc6257f2227a99beffb1405d4bfd5bdec12539fde0a9ae66e3865a6e4785fu256;
const Qrx: u256  = 0xfe7a7ce1a2ccc939ed1f9c111eda6cbd56659574a632adddf01420a03ab3dbdu256;
const Qry: u256  = 0x199e3d497051629a5a9256871d04007760f7b9cfd071cd7c7ecae57eba577dc3u256;
const Qox: u256  = 0x12e60366cf65d8075e8323b4901c327975ccd65c8099545b69bfc74d550f29c2u256;
const Qoy: u256  = 0x1a88c9d927c1544a000aac6b4b790943b82eacec71818df67a5af62415d56b3cu256;
const Qcx: u256  = 0x0u256;
const Qcy: u256  = 0x0u256;
const S1x: u256  = 0x161290a46dfaa41fb95b6e638ebcbe4c70dad8aa3b037acf8e3dd0edf9007d9fu256;
const S1y: u256  = 0x135e57e5cddfacec05163e20b5e06dcae4c48d41ce60ebb9891eecc233bdaad5u256;
const S2x: u256  = 0xaac7d6f6a38ec02534a66751c1187ee71e008fbb785627c67495ed89408a20u256;
const S2y: u256  = 0x1f71f2bbc8116d6a4a01426bdfa8fa530567229617281c420be7450d10d9f715u256;
const S3x: u256  = 0x253b99253a85cc6aafeed98d2faac282b1ca968ebfad1e4e6bc6175fca522e94u256;
const S3y: u256  = 0x99316deda740d633d42b223d6a9a056ca722c8369f4d7a3ef35e051211fe40au256;
const k1: u256   = 0x2u256;
const k2: u256   = 0x3u256;
const X2x1: u256 = 0xc1d680c2f37096c31e7291987346ef5924e35113defb301e6d16cc7838078e4u256;
const X2x2: u256 = 0xbad11ec876d25d407f42cfd057928f01cb833839dd05df6a6ec301d8506466du256;
const X2y1: u256 = 0x880813632ca0535817a0b5a99e30072c16a287fe5b6949690c6792090e5d659u256;
const X2y2: u256 = 0x272b081cb84fe424a9c0baa28e9552abe502db30f3f3b57f7e51f21d1a0cf02eu256;

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

abi PlonkVerifier {
  fn verify(proof: Proof, pubInput: [u256;1]) -> bool;
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
    let power = 11;
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

impl PlonkVerifier for Contract {
  fn verify(proof: Proof, pubInput: [u256;1]) -> bool {
      proof.verify(pubInput)
  }
}

fn get_test_proof() -> Proof {
    let proof_A = G1Point{
      x: 0x03618765578723a3007c7307459f714a8ad0abf127d1d03f5941d0ef98fb3517u256,
      y: 0x166b1a9cd6b95072a5171d9b2c39fa40e09cf4c56f49ad64552ec343e71412c0u256
    };
    let proof_B = G1Point{
      x: 0x0c16e0ef7b10c89f84e065b34ff5e6727443c729687f887eb99224fcf9fdc199u256,
      y: 0x280e251de1f8fb27d7954f51226541b9275bc3e7f49887a33a4abb71867aac20u256
    };
    let proof_C = G1Point{
      x: 0x112178e206afd94afdc5382bbd29e11bf42acc58ba2abba243b07dbf78190fcdu256,
      y: 0x2620a43851c65e50b31095d8e665eda81071f57e876fc296616b87dfa005798du256
    };
    let proof_Z = G1Point{
      x: 0x08fc57ed374e950334f87bb22044a9e325bcae3240b2aece2324008d5b0d6e6du256,
      y: 0x2d8ff5876ac2271fca1c33369adf647c36a6b00542a0abfb83023cd620283020u256
    };
    let proof_T1 = G1Point{
      x: 0x18f85564bccfc77d56660bc9981f2c543e747b71b203a8d0a91dfcce50cf4adbu256,
      y: 0x0e8b209ae831b7144dd81c871e81f0ab278e1696f53841233d3ee51d09c6bcd9u256
    };
    let proof_T2 = G1Point{
      x: 0x17fd0eb60c51037364efcead597e1d9bd6460b2532aab73e280998a478d0d290u256,
      y: 0x27ccd04ff57cdd36bbd631af548c1834745303eef91ead7893d4acdbba4bcb80u256
    };
    let proof_T3 = G1Point{
      x: 0x06d02fe0c85bbc52b02177f7bdb2dc865b98704b354073219bd196b520a2cf18u256,
      y: 0x1ddf3e8658c7185f57b3f081672d5d2b6f5862c06e2b2ac13fa01f32d3af10bcu256
    };
    let proof_Wxi = G1Point{
      x: 0x13bbdbaabd814460f5521e6c3e79908c82ec82091c0110811c03347941ddb49cu256,
      y: 0x15ce85b2f0a8703eff8f870999e1ec1e8cbaec80863670da651c1f50541638b5u256
    };
    let proof_Wxiw = G1Point{
      x: 0x18c11243b75765c85d381199e961599a258e7c1153115bda9c057aeace228ec7u256,
      y: 0x18f0ab9da5c61b76ee039bee284da827a956b340956619771372f9a0418592dfu256
    };

    // Scalar values
    let eval_a = 0x1613045374eefb0a45f76b9f9ab656e96048ea161ae1b2dc9a5da5bc29bb652cu256;
    let eval_b = 0x17041ee34f3535cd93a4ba84fb14ccf3efdf8c9bc7a6d1b9711ce8b49edddaddu256;
    let eval_c = 0x2c4efe5b1ea056cd989493e5ddd05cf5320f77befd3d2499aeae5f86c42fae58u256;
    let eval_s1 = 0x1a53dd161c9ef92094825340d3bf5546e68c6456030d79c4cbcce67b1de4719du256;
    let eval_s2 = 0x12acc7b30823d540ce3a9e8531dcbee8dac99ce5b012e80f12e6624c9f0c5652u256;
    let eval_zw = 0x0f2ecb8cf64dbfa1d93c8fb63d93e2d4a33ebed3cdbef72c4d43d5eb87ff2bc5u256;

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
      let publicInput: [u256; 1] = [0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256];
      assert(proof.verify(publicInput));
  }