contract;

use sway_ecc::{G1Point, G2Point, Scalar};

// Scalar field size
const R: u256 = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001u256;
// Base field size
const Q: u256 = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47u256;

// Verification Key data
const ALPHA = G1Point {
    x: 0x259e483eac6675639c8131203859654b101d60953b0c74ed9e27c717384d6b8du256,
    y: 0x19818d29ec709a530771dea371b7819c73d4dcbe0f5fad3bf858775842a91d3fu256,
};
const BETA = G2Point {
    x: [
        0x11ad0d4755480d587f72c0766c7182573a7f61f3f84090a88f5a8d24c1276da0u256,
        0x2eae6bd9a84d2d05f8060973e06a8edcf10ff0bd697d746145d5395f25950bcau256,
    ],
    y: [
        0x054ddc63046f86117db68009d923900a9769a7bbc7ff819cbe3eaedd9866b902u256,
        0x0dd39ace0502b09ce211468563219d704ba3d199b2e4b372d2f11c06a8a4e6fau256,
    ],
};
const GAMMA = G2Point {
    x: [
        0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2u256,
        0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6edu256,
    ],
    y: [
        0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975bu256,
        0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daau256,
    ],
};
const DELTA = G2Point {
    x: [
        0x05d482d0b371bbebdd56d9ceeeba2c600ccee0b2e08fa991867b6cad6f21d0ccu256,
        0x0f24d96d5f427fcc4a30fe65a2a73162de28bd6324905f22c6437b488c5515e1u256,
    ],
    y: [
        0x08f9635c9048c9e62ee2324f2d279cc108a43343a399984545e4114fdb784d20u256,
        0x1a777d491272a6ef72a0030bded32fe11b990d828c4272ffe0b7448c71758459u256,
    ],
};

const PUBLIC_INPUT_LEN = 1;

// IC depends on the number of public inputs
const IC: [G1Point; 2] = [
    G1Point {
        x: 0xcb15ff28cc32c411dc8518ed7b84462e03569a2c8a3a27b8c6fb77318a1b798u256,
        y: 0x5cbe1e78918f9f672d64b6dd43ded30e335b1bca19ecb55974e7a22570504d1u256,
    },
    G1Point {
        x: 0x1ea2b93521113cb42d03ef7854eb2ba2bcafb93f523d9cc24957fedd7e10536cu256,
        y: 0x2b77fa51d4fff879e6203624c339f06bf92057921ab038b72e58077ea6ff9fcdu256,
    },
];

abi Groth16Verifier {
    fn verify_proof(
        p_a: [u256; 2],
        p_b: [[u256; 2]; 2],
        p_c: [u256; 2],
        pub_signals: [u256; 1],
    ) -> bool;
}

impl Groth16Verifier for Contract {
    fn verify_proof(
        p_a: [u256; 2],
        p_b: [[u256; 2]; 2],
        p_c: [u256; 2],
        pub_signals: [u256; 1],
    ) -> bool {
        // check inputs < R
        let mut i = 0;
        while i < PUBLIC_INPUT_LEN {
            if pub_signals[i] >= R {
                return false;
            }
            i += 1;
        }
        // check element in proof < Q
        if p_a[0] >= Q || p_a[1] >= Q || p_b[0][0] >= Q || p_b[0][1] >= Q || p_b[1][0] >= Q || p_b[1][1] >= Q || p_c[0] >= Q || p_c[1] >= Q {
            return false;
        };

        // compute the linear combination of X
        let mut i = 0;
        let mut x = G1Point{
                x: IC[i].x,
                y: IC[i].y,
            };

        while i < PUBLIC_INPUT_LEN {
            let a_i = Scalar {
                x: pub_signals[i],
            };
            let ic_i = G1Point {
                x: IC[i+1].x,
                y: IC[i+1].y,
            };
            x = G1Point::point_add(x, G1Point::scalar_mul(ic_i, a_i));
            i+=1;
        };

        // check the pairing equation
        let mut pairing_input: [u256; 24] = [0; 24];
        // neg A
        let a_neg = G1Point{
            x: p_a[0],
            y: (Q - p_a[1]) % Q
        };

        // -A
        pairing_input[0] = a_neg.x;
        pairing_input[1] = a_neg.y;
        // B
        pairing_input[2] = p_b[0][0];
        pairing_input[3] = p_b[0][1];
        pairing_input[4] = p_b[1][0];
        pairing_input[5] = p_b[1][1];
        // alpha
        pairing_input[6] = ALPHA.x;
        pairing_input[7] = ALPHA.y;
        // beta
        pairing_input[8] = BETA.x[0];
        pairing_input[9] = BETA.x[1];
        pairing_input[10] = BETA.y[0];
        pairing_input[11] = BETA.y[1];
        // x
        pairing_input[12] = x.x;
        pairing_input[13] = x.y;
        // gamma
        pairing_input[14] = GAMMA.x[0];
        pairing_input[15] = GAMMA.x[1];
        pairing_input[16] = GAMMA.y[0];
        pairing_input[17] = GAMMA.y[1];
        // c
        pairing_input[18] = p_c[0];
        pairing_input[19] = p_c[1];
        // delta
        pairing_input[20] = DELTA.x[0];
        pairing_input[21] = DELTA.x[1];
        pairing_input[22] = DELTA.y[0];
        pairing_input[23] = DELTA.y[1];

        let curve_id: u32 = 0;
        let groups_of_points: u32 = 4;

        let result = asm(rA, rB: curve_id, rC: groups_of_points, rD: pairing_input) {
            epar rA rB rC rD;
            rA: u32
        };

        result != 0

    }
}

#[test]
fn test_verify() {
    let p_a:[u256;2] =  [0x0266fc01cec5ae32b09abe1b862de0aa2e3d0189db5bce50b1c4362a79a03748u256,0x098897f90d14596d7eb495e07be25cb1dc66e9bab56743c70b34e60705c78a6fu256];
    let p_b:[[u256; 2]; 2] = [[0x104a3849945b63645a56a0122aa0c6f549a3cf6934a5ce1cfbbc4a925653e16bu256,0x151ed01ed44f1a7c116ae983142a093f9c202e91d98d00db37cd0a811888df4au256],[0x046b03e442424ef0fcd82a9828ee795b264c3d0ace1c365e787918abc3e206f5u256,0x122ef3c96d107c917fcb65d70bc2caad518b2405117a95d0a0c103ee40182c1cu256]];
    let p_c:[u256;2] = [0x28da51f1043f5a7e1e4513801e19c2041f321581b10b54324b912cc47715985cu256,0x187905623652f34980ffbce0d351648d9d1343bbee8b8277e5af00b27220de47u256];
    let pub_signals: [u256; 1] = [0x0000000000000000000000000000000000000000000000000000000000000021u256];
    let verifier = abi(Groth16Verifier, CONTRACT_ID);
    let r = verifier.verify_proof{}(p_a, p_b, p_c, pub_signals);
    assert(r)
}
