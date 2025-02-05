contract;
mod lib;
use lib::{G1Point, G2Point, Scalar, on_bn128_curve};
use std::hash::Hash;
use std::hash::{keccak256, sha256};
use std::bytes::Bytes;
use std::bytes_conversions::u256::*;

// Plonk Verifier
// Follows Snarkjs Solidity implementation and additional notes from original Plonk paper

const ZERO: u256 = 0;

struct VerificationKey {
    // Scalars
    pub w1: Scalar,      // Root of unity
    pub q: Scalar,       // Scalar field size
    pub qf: Scalar,      // Base field size

    // G1 Points
    pub G1: G1Point,     // Generator of G1 ([1]_1)
    
    // G2 Points
    pub G2: G2Point,     // Generator of G2 ([1]_2)

    // Selector polynomials (G1 points)
    pub Qm: G1Point,     // Q_m(X)
    pub Ql: G1Point,     // Q_l(X)
    pub Qr: G1Point,     // Q_r(X)
    pub Qo: G1Point,     // Q_o(X)
    pub Qc: G1Point,     // Q_c(X)

    // Permutation polynomials (G1 points)
    pub S1: G1Point,     // S_1(X)
    pub S2: G1Point,     // S_2(X)
    pub S3: G1Point,     // S_3(X)

    // Scalars for permutation
    pub k1: Scalar,      // k1 (permutation factor)
    pub k2: Scalar,      // k2 (permutation factor)

    // Circuit metadata
    pub n: u32,          // Circuit size, power of 2
    pub nPublic: u16,    // Number of public inputs
    pub nLagrange: u16,  // Number of Lagrange polynomials

    // Additional points
    pub X2: G2Point,     // X2 point for additional checks
}

const vk = VerificationKey {
    w1: Scalar { x: 0x27a358499c5042bb4027fd7a5355d71b8c12c177494f0cad00a58f9769a2ee2u256 },
    q: Scalar { x: 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001u256 },
    qf: Scalar { x: 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47u256 },
    
    G1: G1Point { 
        x: 0x1u256, 
        y: 0x2u256 
    },
    
    G2: G2Point {
        x: [
            0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6edu256,
            0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2u256,
        ],
        y: [
            0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daau256,
            0x90689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975bu256,
        ]
    },
    
    Qm: G1Point { 
        x: 0x257a39d7a5bddadfbabe8ebd7df4c3521a1dbdd8cbbe6332cd609c8612a2ba29u256,
        y: 0xbaa231049c9662e040924014e3558475d2b6b4c5da421bfbb618dc863697bc8u256,
    },
    
    Ql: G1Point { 
        x: 0xa2b203e18cac0013e11d51531fdc50be9787f3ead6af16167163cf546d60aaeu256,
        y: 0x70fc6257f2227a99beffb1405d4bfd5bdec12539fde0a9ae66e3865a6e4785fu256,
    },
    
    Qr: G1Point { 
        x: 0xfe7a7ce1a2ccc939ed1f9c111eda6cbd56659574a632adddf01420a03ab3dbdu256,
        y: 0x199e3d497051629a5a9256871d04007760f7b9cfd071cd7c7ecae57eba577dc3u256,
    },
    
    Qo: G1Point { 
        x: 0x12e60366cf65d8075e8323b4901c327975ccd65c8099545b69bfc74d550f29c2u256,
        y: 0x1a88c9d927c1544a000aac6b4b790943b82eacec71818df67a5af62415d56b3cu256,
    },
    
    Qc: G1Point { 
        x: 0x0u256, 
        y: 0x0u256 
    },
    
    S1: G1Point { 
        x: 0x161290a46dfaa41fb95b6e638ebcbe4c70dad8aa3b037acf8e3dd0edf9007d9fu256,
        y: 0x135e57e5cddfacec05163e20b5e06dcae4c48d41ce60ebb9891eecc233bdaad5u256,
    },
    
    S2: G1Point { 
        x: 0xaac7d6f6a38ec02534a66751c1187ee71e008fbb785627c67495ed89408a20u256,
        y: 0x1f71f2bbc8116d6a4a01426bdfa8fa530567229617281c420be7450d10d9f715u256,
    },
    
    S3: G1Point { 
        x: 0x253b99253a85cc6aafeed98d2faac282b1ca968ebfad1e4e6bc6175fca522e94u256,
        y: 0x99316deda740d633d42b223d6a9a056ca722c8369f4d7a3ef35e051211fe40au256,
    },
    
    k1: Scalar { x: 0x2u256 },
    k2: Scalar { x: 0x3u256 },
    
    n: 2048,
    nPublic: 1,
    nLagrange: 1,

    X2: G2Point {
        x: [
            0xc1d680c2f37096c31e7291987346ef5924e35113defb301e6d16cc7838078e4u256,
            0xbad11ec876d25d407f42cfd057928f01cb833839dd05df6a6ec301d8506466du256,
        ],
        y: [
            0x880813632ca0535817a0b5a99e30072c16a287fe5b6949690c6792090e5d659u256,
            0x272b081cb84fe424a9c0baa28e9552abe502db30f3f3b57f7e51f21d1a0cf02eu256,
        ]
    },
};

pub fn is_field(val: Scalar, q: u256) -> bool {
  val.x < q
}

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
  pub eval_a: Scalar,
  pub eval_b: Scalar,
  pub eval_c: Scalar,
  pub eval_s1: Scalar,
  pub eval_s2: Scalar,
  pub eval_zw: Scalar,
}

impl Proof {

    // beta, gamma, alpha, xi (=zeta), v, u
    fn get_challenges(self, publicInput: u256) -> [b256;6] {
        let mut transcript: Bytes = Bytes::new();

        ////// BETA
        // Qmx
        // Qmy
        transcript.append(vk.Qm.bytes());
        // Qlx
        // Qly
        transcript.append(vk.Ql.bytes());
        // Qrx
        // Qry
        transcript.append(vk.Qr.bytes());
        // Qox
        // Qoy
        transcript.append(vk.Qo.bytes());
        // Qcx
        // Qcy
        transcript.append(vk.Qc.bytes());
        // S1x
        // S1y
        transcript.append(vk.S1.bytes());
        // S2x
        // S2y
        transcript.append(vk.S2.bytes());
        // S3x
        // S3y
        transcript.append(vk.S3.bytes());
        // 32 bytes of public data
        transcript.append(Bytes::from(publicInput.to_be_bytes()));
        // 64 bytes of pA
        transcript.append(self.proof_A.bytes());
        // 64 bytes of pB
        transcript.append(self.proof_B.bytes());
        // 64 bytes of pC
        transcript.append(self.proof_C.bytes());
        // beta = hash(transcript) mod q
        let beta: b256 = keccak256(transcript);
        asm (rA: beta, rC: ZERO, rD: vk.q.x) {
            wqam rA rA rC rD;
        };
        
        ////// GAMMA
        // gamma = hash(beta) mod q
        // Note: this follows snarkjs Plonk verifier beta = hash(transcript) and gamma = hash(beta)
        // While the paper does beta = hash(transcript, 0) and gamma=hash(transcript,1))
        let gamma: b256 = keccak256(beta);
        asm (rA: gamma, rC: ZERO, rD: vk.q.x) {
            wqam rA rA rC rD;
        };
        
        ////// ALPHA
        // alpha = hash(beta, gamma, proof_Z) mod q
        let mut transcript: Bytes = Bytes::new();
        transcript.append(Bytes::from(beta));
        transcript.append(Bytes::from(gamma));
        transcript.append(self.proof_Z.bytes());
        let alpha: b256 = keccak256(transcript);
        asm (rA: alpha, rC: ZERO, rD: vk.q.x) {
            wqam rA rA rC rD;
        };
        
        ////// XI (xi in Plonk paper)
        // xi = hash(alpha, proof_T1, proof_T2, proof_T3) mod qs
        let mut transcript: Bytes = Bytes::new();
        transcript.append(Bytes::from(alpha));
        transcript.append(self.proof_T1.bytes());
        transcript.append(self.proof_T2.bytes());
        transcript.append(self.proof_T3.bytes());
        let xi: b256 = keccak256(transcript);
        asm (rA: xi, rC: ZERO, rD: vk.q.x) {
            wqam rA rA rC rD;
        };

        ////// V
        // v = hash(xi, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw)
        let mut transcript: Bytes = Bytes::new();
        transcript.append(Bytes::from(xi));
        transcript.append(self.eval_a.bytes());
        transcript.append(self.eval_b.bytes());
        transcript.append(self.eval_c.bytes());
        transcript.append(self.eval_s1.bytes());
        transcript.append(self.eval_s2.bytes());
        transcript.append(self.eval_zw.bytes());
        let v: b256 = keccak256(transcript);
        asm (rA: v, rC: ZERO, rD: vk.q.x) {
            wqam rA rA rC rD;
        };

        ////// U
        // u = hash(wxi, wxiw)
        let mut transcript: Bytes = Bytes::new();
        transcript.append(self.proof_Wxi.bytes());
        transcript.append(self.proof_Wxiw.bytes());
        let u: b256 = keccak256(transcript);
        asm (rA: u, rC: ZERO, rD: vk.q.x) {
            wqam rA rA rC rD;
        };

        return [beta, gamma, alpha, xi, v, u]
    }

    // TODO calculate inverse to finish up the value
    // num, denom, xi^n
    fn calculateLagrange(self, xi: u256, w: u256) -> (u256, u256, u256) {
      // n(xi-w) mod q
      let mut denom: u256 = 0;
      let temp = xi - w;
      let n = u256::from(vk.n);
      // mem[$rA,32] = (b*c)%d
      asm (rA: denom, rB: temp, rC: n, rD: vk.q.x) {
        wqmm rA rB rC rD;
      };
      
      // 2. xi^n-w, where in practice n is a power of 2
      let power = 11; // this is specific to the n (vk.n)
      let mut i = 0;
      let mut xi_pow_n: u256 = xi;
      while i < power {
          // mem[$rA,32] = (b*c)%d
          asm (rA: xi_pow_n, rB: xi_pow_n, rC: xi_pow_n, rD: vk.q.x) {
            wqmm rA rB rC rD;
          };

          i = i + 1;
      }
      let num: u256 = xi_pow_n - w;

      // TODO invert denom
      // return (xiˆn-w) / n*(xi-w), xi_pow_n
      return (num, denom, xi_pow_n);
    }
      
    // In this code, l = 1
    // w_1*L_1(xi), 
    // where w_1 is the first public signal
    // and L_1(xi)=pEval_l1
    fn calculatePI(self, pEval_l1: u256, publicInput: u256) -> u256 {
        let mut res: u256 = 0;
        // pEval_l1*publicInput mod q
        asm (rA: res, rB: pEval_l1, rC: publicInput, rD: vk.q.x) {
            wqmm rA rB rC rD;
        };
        // Same as in Solidity code, negate PI
        return vk.q.x - res;
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
        asm (rA: second_term, rB: pEval_l1, rC: alpha_squared, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        
        ///// THIRD TERM
        // part 1: (¯a + β¯sσ1 + γ)
        
        // Step 1: third_term_1 =  β¯sσ1
        let mut third_term_1: u256 = 0;
        asm (rA: third_term_1, rB: beta, rC: self.eval_s1, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        // Step 2: third_term_1 =  ¯a + β¯sσ1
        asm (rA: third_term_1, rB: self.eval_a, rC: third_term_1, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        // Step 3: third_term_1 = ¯a + β¯sσ1 + γ
        asm (rA: third_term_1, rB: third_term_1, rC: gamma, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // part 2: (¯b + β¯sσ2 + γ)
        let mut third_term_2: u256 = 0;
        asm (rA: third_term_2, rB: beta, rC: self.eval_s2, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: third_term_2, rB: self.eval_b, rC: third_term_2, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        asm (rA: third_term_2, rB: third_term_2, rC: gamma, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // part 3: (¯c + γ)
        let mut third_term_3: u256 = 0;
        asm (rA: third_term_3, rB: self.eval_c, rC: gamma, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // α(¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)(¯c + γ)¯zω
        let mut temp0: u256 = 0;
        asm (rA: temp0, rB: alpha, rC: third_term_1, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        let mut temp1: u256 = 0;
        asm (rA: temp1, rB: third_term_2, rC: third_term_3, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        let mut third_term: u256 = 0;
        asm (rA: third_term, rB: self.eval_zw, rC: temp0, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: third_term, rB: third_term, rC: temp1, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };

        // PI(z) − L1(z)α2 − α(¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)(¯c + γ)¯zω
        // PI(z) + (q - L1(z)α2) + (q - α(¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)(¯c + γ)¯zω)

        let mut q_minus_second: u256 = vk.q.x - second_term;
        let mut q_minus_third: u256 = vk.q.x - third_term;

        let mut res: u256 = 0;
        asm (rA: res, rB: PIz, rC: q_minus_second, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        asm (rA: res, rB: res, rC: q_minus_third, rD: vk.q.x) {
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
        let mut point_term_1 = vk.Qc;
        // eval_a*eval_b*Gm
        let mut temp0: u256 = 0;
        asm (rA: temp0, rB: self.eval_a, rC: self.eval_b, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        let temp0_point = vk.Qm.scalar_mul(Scalar { x: temp0 });
        point_term_1 = point_term_1.point_add(temp0_point);
        //eval_a*Ql
        let temp1_point = vk.Ql.scalar_mul(self.eval_a);
        point_term_1 = point_term_1.point_add(temp1_point);
        //eval_b*Qr
        let temp2_point = vk.Qr.scalar_mul(self.eval_b);
        point_term_1 = point_term_1.point_add(temp2_point);
        //eval_c*Qo
        let temp3_point = vk.Qo.scalar_mul(self.eval_c);
        point_term_1 = point_term_1.point_add(temp3_point);

        //// TERM 2
        // (¯a + βz + γ)
        let mut betaxi: u256 = 0;
        asm (rA: betaxi, rB: beta, rC: xi, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        let mut val1: u256 = 0;
        asm (rA: val1, rB: betaxi, rC: self.eval_a, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        asm (rA: val1, rB: val1, rC: gamma, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // (¯b + βk1z + γ)
        let mut val2: u256 = 0;
        asm (rA: val2, rB: betaxi, rC: vk.k1, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: val2, rB: val2, rC: self.eval_b, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        asm (rA: val2, rB: val2, rC: gamma, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // (¯c + βk2z + γ)
        let mut val3: u256 = 0;
        asm (rA: val3, rB: betaxi, rC: vk.k2, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: val3, rB: val3, rC: self.eval_c, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        asm (rA: val3, rB: val3, rC: gamma, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // (¯a + βz + γ)(¯b + βk1z + γ)(¯c + βk2z + γ)α
        let mut d2a: u256 = 0;
        asm (rA: d2a, rB: val1, rC: val2, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: d2a, rB: d2a, rC: val3, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: d2a, rB: d2a, rC: alpha, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };

        // L1(z)α2
        let mut d3a: u256 = 0;
        asm (rA: d3a, rB: pEval_l1, rC: alpha_squared, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };

        // (¯a + βz + γ)(¯b + βk1z + γ)(¯c + βk2z + γ)α + L1(z)α2 + u
        let mut scalar_term_2: u256 = 0;
        asm (rA: scalar_term_2, rB: d2a, rC: d3a, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        asm (rA: scalar_term_2, rB: scalar_term_2, rC: u, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // ((¯a + βz + γ)(¯b + βk1z + γ)(¯c + βk2z + γ)α + L1(z)α2 + u) · [z]1
        let point_term2 = self.proof_Z.scalar_mul(Scalar{x: scalar_term_2});

        //// TERM 3
        // (¯a + β¯sσ1 + γ)
        asm (rA: val1, rB: beta, rC: self.eval_s1, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: val1, rB: val1, rC: self.eval_a, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        asm (rA: val1, rB: val1, rC: gamma, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // (¯b + β¯sσ2 + γ)
        asm (rA: val2, rB: beta, rC: self.eval_s2, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: val2, rB: val2, rC: self.eval_b, rD: vk.q.x) {
          wqam rA rB rC rD;
        };
        asm (rA: val2, rB: val2, rC: gamma, rD: vk.q.x) {
          wqam rA rB rC rD;
        };

        // αβ¯zω
        asm (rA: val3, rB: alpha, rC: beta, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: val3, rB: val3, rC: self.eval_zw, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };

        // (¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)αβ¯zω
        let mut scalar_term3: u256 = 0;
        asm (rA: scalar_term3, rB: val1, rC: val2, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: scalar_term3, rB: scalar_term3, rC: val3, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };

        // (¯a + β¯sσ1 + γ)(¯b + β¯sσ2 + γ)αβ¯zω · [sσ3]1
        let point_term3 = vk.S3.scalar_mul(Scalar{x: scalar_term3});

        //// TERM 4
        let mut point_term4: G1Point = self.proof_T1;
        // xi^n[t_mid]1
        let mut temp_point: G1Point = self.proof_T2.scalar_mul(Scalar{ x:xi_pow_n });
        point_term4 = point_term4.point_add(temp_point);
        
        // xi^2n
        asm (rA: val2, rB: xi_pow_n, rC: xi_pow_n, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        // xi^2n · [t_hi]1
        temp_point = self.proof_T3.scalar_mul(Scalar{ x:val2 });
        point_term4 = point_term4.point_add(temp_point);

        // ZH(z)([tlo]1 + zn · [tmid]1 + z2n · [thi]1)
        point_term4 = point_term4.scalar_mul(Scalar {x: xi_pow_n - 1 });

        // negate point term3
        let neg_y_3: u256 = vk.qf.x - point_term3.y;
        let neg_term3 = G1Point{
            x: point_term3.x,
            y: neg_y_3
        };
        let mut neg_y_bytes: [u8; 64] = neg_term3.to_bytes();

        // negate point term4
        let neg_y_4 = vk.qf.x - point_term4.y;
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
      v: Scalar,
      v2: Scalar,
      v3: Scalar,
      v4: Scalar,
      v5: Scalar,
      D: G1Point
    ) -> G1Point {
        // D + v · [a]1
        let mut temp: G1Point = self.proof_A.scalar_mul(v);
        let mut res: G1Point = D.point_add(temp);
        // v2 · [b]1
        temp = self.proof_B.scalar_mul(v2);
        res = res.point_add(temp);
        // v3 · [c]1
        temp = self.proof_C.scalar_mul(v3);
        res = res.point_add(temp);
        // v4 · [sσ1]1
        temp = vk.S1.scalar_mul(v4);
        res = res.point_add(temp);
        // v5 · [sσ2]1
        temp = vk.S2.scalar_mul(v5);
        res = res.point_add(temp);
        return res; 
    }

    fn calculateE(self,
      r0: u256,
      u: Scalar,
      v: Scalar,
      v2: Scalar,
      v3: Scalar,
      v4: Scalar,
      v5: Scalar,
      ) -> G1Point {
        // −r0 + v¯a + v2¯b + v3¯c + v4¯sσ1 + v5¯sσ2 + u¯zω
        // q-r0
        let mut acc_scalar: u256 = vk.q.x - r0;
        let mut temp: u256 = 0;
        asm (rA: temp, rB: v, rC: self.eval_a, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        acc_scalar += temp;
        asm (rA: temp, rB: v2, rC: self.eval_b, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        acc_scalar += temp;
        asm (rA: temp, rB: v3, rC: self.eval_c, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        acc_scalar += temp;
        asm (rA: temp, rB: v4, rC: self.eval_s1, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        acc_scalar += temp;
        asm (rA: temp, rB: v5, rC: self.eval_s2, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        acc_scalar += temp;
        asm (rA: temp, rB: u, rC: self.eval_zw, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        acc_scalar += temp;
        let res = vk.G1.scalar_mul(Scalar { x: acc_scalar });
        return res; 
    }

    // In this case, public input has length 1
    pub fn verify(self, publicInput: u256) -> bool {
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
        // 2. Validate (¯a, ¯b, ¯c,¯sσ1,¯sσ2, ¯zω) ∈ F6 (scalar field, q)
        if !(is_field(self.eval_a, vk.q.x)
            && is_field(self.eval_b, vk.q.x)
            && is_field(self.eval_c, vk.q.x)
            && is_field(self.eval_s1, vk.q.x)
            && is_field(self.eval_s2, vk.q.x)
            && is_field(self.eval_zw, vk.q.x)) {
          return false; 
        }
        // 3. Validate public input 
        // (wi)i∈[ℓ] ∈ Fℓ
        if !is_field(Scalar {x: publicInput}, vk.q.x) {
          return false; 
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
        let w: u256 = 1;
        let (num, denom, xi_pow_n) = self.calculateLagrange(xi, w);

        // Step 7: compute PI (public input polynomial evaluation)
        // sum(w_i*L_i(xi)) 
        // Following Solidity implementation -sum(w_i*L_i(xi)) 
        // zeta = xi in Solidity Verifier
        // TODO
        // temporarily, take hardcoded value, until inversion has been implemented
        let pEval_l1_temp = u256::from(0x0f54b0a27de056bddb97b2c04c514603caba86c9c0a2569d829216adfc954077);
        let PI = self.calculatePI(pEval_l1_temp, publicInput);

        // Step 8: compute R0
        let mut alpha_squared: u256 = 0;
        // mem[$rA,32] = (b*c)%d
        asm (rA: alpha_squared, rB: alpha, rC: alpha, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        let R0 = self.calculateR0(
          PI, 
          pEval_l1_temp,
          alpha,
          alpha_squared,
          beta,
          gamma
        );
        
        // Step 9: compute D
        let D = self.calculateD(
          pEval_l1_temp,
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
        asm (rA: v2, rB: v, rC: v, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: v3, rB: v2, rC: v, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: v4, rB: v3, rC: v, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        asm (rA: v5, rB: v4, rC: v, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        let v_scalar = Scalar { x: v };
        let v2_scalar = Scalar { x: v2 };
        let v3_scalar = Scalar { x: v3 };
        let v4_scalar = Scalar { x: v4 };
        let v5_scalar = Scalar { x: v5 };
        let F: G1Point = self.calculateF(v_scalar, v2_scalar, v3_scalar, v4_scalar, v5_scalar, D);

        // Step 11: compute E
        let u_scalar = Scalar { x: u };
        let E: G1Point = self.calculateE(R0, u_scalar, v_scalar, v2_scalar, v3_scalar, v4_scalar, v5_scalar);

        // Step 12: check pairing
        // A1 = [Wz]1 + u · [Wzω]1
        let mut a1: G1Point = self.proof_Wxiw.scalar_mul(u_scalar);
        a1 = a1.point_add(self.proof_Wxi);
        let a1_neg = G1Point {
          x: a1.x,
          y: (vk.qf.x - a1.y) % vk.qf.x
        };

        // B1 = z · [Wz]1 + uzω · [Wzω]1 + [F]1 − [E]1
        let mut b1: G1Point = self.proof_Wxi.scalar_mul(Scalar {x: xi });
        let mut temp: u256 = 0;
        asm (rA: temp, rB: u, rC: xi, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };
        let w1: u256 = 0x027a358499c5042bb4027fd7a5355d71b8c12c177494f0cad00a58f9769a2ee2u256;
        asm (rA: temp, rB: temp, rC: w1, rD: vk.q.x) {
          wqmm rA rB rC rD;
        };

        b1 = b1.point_add(self.proof_Wxiw.scalar_mul(Scalar { x: temp }));
        b1 = b1.point_add(F);
        let E_neg = G1Point {
            x: E.x,
            y: (vk.qf.x - E.y) % vk.qf.x
        };
        b1 = b1.point_add(E_neg);

        // Serialize inputs for EPAR
        let mut pairing_input: [u256; 12] = [0; 12];

        // Pairing input: -A1, X2
        pairing_input[0] = a1_neg.x;
        pairing_input[1] = a1_neg.y;
        // g2: [[x1, x0], [y1, y0]]
        pairing_input[3] = vk.X2.x[0];
        pairing_input[2] = vk.X2.x[1];
        pairing_input[5] = vk.X2.y[0];
        pairing_input[4] = vk.X2.y[1];

        // Pairing input: B1, [1]_2
        pairing_input[6] = b1.x;
        pairing_input[7] = b1.y;
        // g2: [[x1, x0], [y1, y0]]
        pairing_input[9] = vk.G2.x[0];
        pairing_input[8] = vk.G2.x[1];
        pairing_input[11] = vk.G2.y[0];
        pairing_input[10] = vk.G2.y[1];

        // Perform pairing check
        let curve_id: u32 = 0;
        let groups_of_points: u32 = 2;
        
        let result: u32 = asm(rA, rB: curve_id, rC: groups_of_points, rD: pairing_input) {
            epar rA rB rC rD;
            rA: u32
        };
        
        result != 0
    }

    // Computes the inverse using the extended euclidean algorithm
    pub fn inverse(a: u256) -> u256 {
      let mut t = 0;
      let mut newt = 1;
      let mut r = vk.q.x;
      let mut newr = a;
      let mut quotient = 0;
      let mut aux = 0;

      while newr != 0 {

        quotient = r / newr;
        // aux = t - quotient*newt
        let mut qt = 0;
        asm (rA: qt, rB: quotient, rC: newt, rD: vk.q.x){
          wqmm rA rB rC rD;
        }
        qt = vk.q.x - qt;
        asm (rA: aux, rB: t, rC: qt, rD: vk.q.x){
          wqam rA rB rC rD;
        }
        t = newt;
        newt = aux;

        // aux = r - quotient*newr
        let mut qr = 0;
        asm (rA: qr, rB: quotient, rC: newr, rD:vk.q.x){
          wqmm rA rB rC rD;
        }
        qr = vk.q.x - qr;
        asm (rA: aux, rB: r, rC: qr, rD: vk.q.x){
          wqam rA rB rC rD;
        }
        r = newr;
        newr = aux;
      };

      t

    }

    // Computes the inverse of an array of values
    // Array length n will change based on the input
    //NOTE - we can use variable Vec here, but this is more suitable for ejs template
    fn inverse_array(ref mut vals: [u256; 3]){

      // aux_array length = n-1
      //NOTE - for array length = 1, aux_array will have type [u256;0], 
      // seems like the compiler won't complain about it
      let mut aux_array: [u256; 2] = [0; 2];
      let mut pos = 1;
      let mut acc = vals[0];
      // calculate acc = vals[0]*vals[1]*...*vals[n]
      // pos < vals length
      while pos < 3 {
        aux_array[pos-1] = acc;
        asm (rA: acc, rB: vals[pos], rC:vk.q.x){
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
        asm (rA: inv, rB: acc, rC: aux_array[pos-1], rD:vk.q.x){
          wqmm rA rB rC rD;
        }
        asm (rA: acc, rB: vals[pos], rC:vk.q.x){
          wqmm rA rA rB rC;
        }
        vals[pos] = inv;
        pos -= 1;
      }
      vals[pos] = acc;
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

    // eval_a
    let eval_a = Scalar {
        x: 0x1613045374eefb0a45f76b9f9ab656e96048ea161ae1b2dc9a5da5bc29bb652cu256,
    }; 
    // eval_b
    let eval_b = Scalar {
        x: 0x17041ee34f3535cd93a4ba84fb14ccf3efdf8c9bc7a6d1b9711ce8b49edddaddu256,
    };
    // eval_c
    let eval_c = Scalar {
        x: 0x2c4efe5b1ea056cd989493e5ddd05cf5320f77befd3d2499aeae5f86c42fae58u256,
    };
    // eval_s1
    let eval_s1 = Scalar {
        x: 0x1a53dd161c9ef92094825340d3bf5546e68c6456030d79c4cbcce67b1de4719du256,
    };
    // eval_s2
    let eval_s2 = Scalar {
        x: 0x12acc7b30823d540ce3a9e8531dcbee8dac99ce5b012e80f12e6624c9f0c5652u256,
    };
    // eval_zw
    let eval_zw = Scalar {
        x: 0x0f2ecb8cf64dbfa1d93c8fb63d93e2d4a33ebed3cdbef72c4d43d5eb87ff2bc5u256,
    };

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
    let publicInput: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
    assert(proof.verify(publicInput));
}

#[test]
fn test_challenges_correct() {
  let proof = get_test_proof();
  let publicInput: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
  let challenges = proof.get_challenges(publicInput);
  // beta = 9039157458725624756817570435850936750907480212061850632293870469811624017805
  assert(challenges[0] == 0x13fbfb586deb4d87a24218bc40e77153fe065b3c8401a0ab729130bb9000ff8d);
  // gamma = 21183458777034922119798033548885077621097219042378882580873372273104224850007
  assert(challenges[1] == 0x2ed569abe2d859b264a1a976feb661c36cd14be653582a385d9d6f8c71451057);
  // alpha = 0x2a266571789ec0ac7ccf08b61ccac16c10e217f0c14b87eada1d6c9fe0e11dac
  assert(challenges[2] == 0x2a266571789ec0ac7ccf08b61ccac16c10e217f0c14b87eada1d6c9fe0e11dac);
  // xi = 5995391859610881302288530115281124419615446175822039475645465975985575599666
  // 0x0d4145839d4fdb8f5fd1533b384e24940bf7114b39cdd16f163838bbaeec9e32
  assert(challenges[3] == 0x0d4145839d4fdb8f5fd1533b384e24940bf7114b39cdd16f163838bbaeec9e32);
  // v = 10198407354444968769398716682395728712793326285861009311402838323692940309090
  // 0x168c1810dcfcb6d7bbee36e0140593e4382ca849c3d6539eaa1e2ebb84e83262
  assert(challenges[4] == 0x168c1810dcfcb6d7bbee36e0140593e4382ca849c3d6539eaa1e2ebb84e83262);
  // u = 14042079368063643215831999264291317274757448834632197026177557057575581413658
  // 0x1f0b89079ac8c5c8af6b1480eb3ad5661afb28ff7a4096f00422dc675d5c711a
  assert(challenges[5] == 0x1f0b89079ac8c5c8af6b1480eb3ad5661afb28ff7a4096f00422dc675d5c711a);
}

#[test]
fn test_calculate_lagrange() {
    let proof = get_test_proof();
    let xi: u256 = u256::from(0x0d4145839d4fdb8f5fd1533b384e24940bf7114b39cdd16f163838bbaeec9e32);
    let w: u256 = 1;
    
    // Returns num and denom separately, since inversion has not been implemented yet
    let (num, denom, xi_pow_n): (u256, u256, u256) = proof.calculateLagrange(xi, w);
    // n(xi-1) mod q: 0x2ec0819de24e1fbb5b015a8726335497c6fe3b4428e53aed437ca9da64f185d0
    assert(denom == u256::from(0x2ec0819de24e1fbb5b015a8726335497c6fe3b4428e53aed437ca9da64f185d0));
    // xi^n - 1 mod q: 0x146415a35241c3305dc90bccb7aae026960aa78d380828893c63a7eb0ea81d97
    assert(num == u256::from(0x146415a35241c3305dc90bccb7aae026960aa78d380828893c63a7eb0ea81d97));

    // TODO add inversion and compute final value
    // let pEval_l1: u256 = proof.calculateLagrange(vk, xi, w);
    // let expected_pEval_l1: u256 = u256::from(0x0e403813acb2c357cb815b0cf271a6f92851f0444081051ea884eb47fa36e9dd);
    // assert(pEval_l1 == expected_pEval_l1);
}

// The Solidity code actually does something slightly different than the paper
// in the paper: pEval_l1*pub[0] mod q
// Solidity code (and this impl): 0-(pEval_l1*pub[0]) mod q
#[test]
fn test_calculate_pi() {
    let proof = get_test_proof();
    // q= 
    // 21888242871839275222246405745257275088548364400416034343698204186575808495617
    let publicInput: u256 = 0x110d778eaf8b8ef7ac10f8ac239a14df0eb292a8d1b71340d527b26301a9ab08u256;
    let pEval_l1 = 0x0f54b0a27de056bddb97b2c04c514603caba86c9c0a2569d829216adfc954077u256;
    let PI = proof.calculatePI(pEval_l1, publicInput);

    // expected value from Solidity contract 0x11c7a56987673d886a2226c9b8a82be88679e261f5b593c0d8b4e9e7b46a9ff6
    // 8042062625007677574890852674071547375005444994579179726790354358024826167286
    assert(PI == 0x11c7a56987673d886a2226c9b8a82be88679e261f5b593c0d8b4e9e7b46a9ff6u256);
}

fn square_mod(alpha: u256, q: u256) -> u256 {
    let mut alpha_squared = 0;
    asm (rA: alpha_squared, rB: alpha, rC: alpha, rD: q) {
      wqmm rA rB rC rD;
    };
    return alpha_squared; 

}

#[test]
fn test_calculate_r0() {
    let proof = get_test_proof();
    let pEval_l1 = 0x0f54b0a27de056bddb97b2c04c514603caba86c9c0a2569d829216adfc954077u256;
    let PIz = 0x11c7a56987673d886a2226c9b8a82be88679e261f5b593c0d8b4e9e7b46a9ff6u256;
    // beta = 9039157458725624756817570435850936750907480212061850632293870469811624017805
    let beta = 0x13fbfb586deb4d87a24218bc40e77153fe065b3c8401a0ab729130bb9000ff8du256;
    // gamma = 21183458777034922119798033548885077621097219042378882580873372273104224850007
    let gamma = 0x2ed569abe2d859b264a1a976feb661c36cd14be653582a385d9d6f8c71451057u256;
    // alpha = 0x2a266571789ec0ac7ccf08b61ccac16c10e217f0c14b87eada1d6c9fe0e11dac
    let alpha = 0x2a266571789ec0ac7ccf08b61ccac16c10e217f0c14b87eada1d6c9fe0e11dacu256;
    let alpha_squared: u256 = square_mod(alpha, vk.q.x);
    
    let R0 = proof.calculateR0(
          PIz,
          pEval_l1,
          alpha,
          alpha_squared,
          beta,
          gamma
        );

    assert(R0 == 0x250144c24fc35df3f70f144497bea4b7efebe7f0d1d73794af958bca5eaba559u256);
}

#[test]
fn test_calculate_d(){
    let proof = get_test_proof();
    let xi: u256 = u256::from(0x0d4145839d4fdb8f5fd1533b384e24940bf7114b39cdd16f163838bbaeec9e32);
    let w: u256 = 1;
    let (num, denom, xi_pow_n): (u256, u256, u256) = proof.calculateLagrange(xi, w);

    let pEval_l1 = 0x0f54b0a27de056bddb97b2c04c514603caba86c9c0a2569d829216adfc954077u256;
    let PIz = 0x11c7a56987673d886a2226c9b8a82be88679e261f5b593c0d8b4e9e7b46a9ff6u256;
    // beta = 9039157458725624756817570435850936750907480212061850632293870469811624017805
    let beta = 0x13fbfb586deb4d87a24218bc40e77153fe065b3c8401a0ab729130bb9000ff8du256;
    // gamma = 21183458777034922119798033548885077621097219042378882580873372273104224850007
    let gamma = 0x2ed569abe2d859b264a1a976feb661c36cd14be653582a385d9d6f8c71451057u256;
    // alpha = 0x2a266571789ec0ac7ccf08b61ccac16c10e217f0c14b87eada1d6c9fe0e11dac
    let alpha = 0x2a266571789ec0ac7ccf08b61ccac16c10e217f0c14b87eada1d6c9fe0e11dacu256;
    let alpha_squared: u256 = square_mod(alpha, vk.q.x);
    let v: u256 = 0x168c1810dcfcb6d7bbee36e0140593e4382ca849c3d6539eaa1e2ebb84e83262u256;
    let u: u256 = 0x1f0b89079ac8c5c8af6b1480eb3ad5661afb28ff7a4096f00422dc675d5c711au256;

    let D = proof.calculateD(
          pEval_l1,
          alpha,
          alpha_squared,
          beta,
          gamma,
          xi,
          xi_pow_n,
          v,
          u
        );

    assert(D.x == 0x12fe947ff97765524ee878302c1f5405173f4c0e6af173d43972bb887d554d96u256);
    assert(D.y == 0x229ba69429158abe97a0fd03ab54a54928a1d36917a5bc79937554563e16d74cu256);
}

#[test]
fn test_calculate_f(){
    let v: u256 = 0x168c1810dcfcb6d7bbee36e0140593e4382ca849c3d6539eaa1e2ebb84e83262u256;
    let proof = get_test_proof();
    let mut v2: u256 = 0;
    let mut v3: u256 = 0;
    let mut v4: u256 = 0;
    let mut v5: u256 = 0;
    asm (rA: v2, rB: v, rC: v, rD: vk.q.x) {
      wqmm rA rB rC rD;
    };
    asm (rA: v3, rB: v2, rC: v, rD: vk.q.x) {
      wqmm rA rB rC rD;
    };
    asm (rA: v4, rB: v3, rC: v, rD: vk.q.x) {
      wqmm rA rB rC rD;
    };
    asm (rA: v5, rB: v4, rC: v, rD: vk.q.x) {
      wqmm rA rB rC rD;
    };
    let v_scalar = Scalar { x: v };
    let v2_scalar = Scalar { x: v2 };
    let v3_scalar = Scalar { x: v3 };
    let v4_scalar = Scalar { x: v4 };
    let v5_scalar = Scalar { x: v5 };
    
    let Dx: u256 = 0x12fe947ff97765524ee878302c1f5405173f4c0e6af173d43972bb887d554d96u256;
    let Dy: u256 = 0x229ba69429158abe97a0fd03ab54a54928a1d36917a5bc79937554563e16d74cu256;
    let D: G1Point = G1Point { x: Dx, y: Dy };
    let F: G1Point = proof.calculateF(v_scalar, v2_scalar, v3_scalar, v4_scalar, v5_scalar, D);
    
    assert(F.x == 0x290426106c4903d8adddc78c613e8b3cc9f8e19fc8c6f97529a36dacff21f1fbu256);
    assert(F.y == 0x2e4ca5ddd8da31b57ebe36cdcd98e9910e6faeb5c478cf8ec7042d70b9e05772u256);
}

#[test]
fn test_calculate_e(){
    let u: u256 = 0x1f0b89079ac8c5c8af6b1480eb3ad5661afb28ff7a4096f00422dc675d5c711au256;
    let v: u256 = 0x168c1810dcfcb6d7bbee36e0140593e4382ca849c3d6539eaa1e2ebb84e83262u256;
    let proof = get_test_proof();
    let mut v2: u256 = 0;
    let mut v3: u256 = 0;
    let mut v4: u256 = 0;
    let mut v5: u256 = 0;
    asm (rA: v2, rB: v, rC: v, rD: vk.q.x) {
      wqmm rA rB rC rD;
    };
    asm (rA: v3, rB: v2, rC: v, rD: vk.q.x) {
      wqmm rA rB rC rD;
    };
    asm (rA: v4, rB: v3, rC: v, rD: vk.q.x) {
      wqmm rA rB rC rD;
    };
    asm (rA: v5, rB: v4, rC: v, rD: vk.q.x) {
      wqmm rA rB rC rD;
    };
    let u_scalar = Scalar { x: u };
    let v_scalar = Scalar { x: v };
    let v2_scalar = Scalar { x: v2 };
    let v3_scalar = Scalar { x: v3 };
    let v4_scalar = Scalar { x: v4 };
    let v5_scalar = Scalar { x: v5 };
    
    let r0: u256 = 0x250144c24fc35df3f70f144497bea4b7efebe7f0d1d73794af958bca5eaba559u256;

    let E: G1Point = proof.calculateE(r0, u_scalar, v_scalar, v2_scalar, v3_scalar, v4_scalar, v5_scalar);
    
    assert(E.x == 0x0dbe940aba2194573041b5fe36a10418ee90345f22573da4f38c6e542f9ff07cu256);
    assert(E.y == 0xbc12210fdfd6c6a8846bae29d8daf0e444ad5d91f65276628ba3157a8b3b4d6u256);
}

#[test]
fn test_inverse(){
  let a = 301904;
  let b = 0x9dfa618dda0b5091f73ed8a5992ef564b412a435024911b16ab1515d9945122u256;
  let c = Proof::inverse(a);
  assert(b==c);
}

#[test]
fn test_inverse_array(){
  let mut a: [u256;3] = [
      301904, 
      0x2042def740cbc01bd03583cf0100e59370229adafbd0f5b62d414e62a0000001u256,
      5756345623
    ];
  let b: [u256;3] = [
      0x9dfa618dda0b5091f73ed8a5992ef564b412a435024911b16ab1515d9945122u256, 
      3, 
      0x247255a45d3f68c85fde42515981851734a718b64d53b279ffbf61e15989032bu256
    ];
  Proof::inverse_array(a);
  assert(b[0]==a[0]);
  assert(b[1]==a[1]);
  assert(b[2]==a[2]);
}