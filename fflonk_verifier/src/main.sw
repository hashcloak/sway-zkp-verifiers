contract;

pub mod ecc;

// https://github.com/man2706kum/sway_ecc/blob/main/verifier_fflonk.sol
// the above contract is generated using snarkjs 
// the file is taken as a reference as of now


abi MyContract {
    fn test_function() -> bool;
}

impl MyContract for Contract {
    fn test_function() -> bool {
        true
    }
}
