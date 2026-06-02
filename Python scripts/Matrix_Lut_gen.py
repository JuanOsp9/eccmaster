import galois
import numpy as np
##Working 100%

# --- CONFIGURATION: BCH(26, 16) ---
#n_mother, k_mother = 31, 21
#target_data = 16
#target_check = 10
#total_width = 26

# --- CONFIGURATION: BCH(44, 32) ---
#n_mother, k_mother = 63, 51   # Uses GF(2^6)
#target_data = 32
#target_check = 12             # 32 + 12 = 44
#total_width = 44

# --- CONFIGURATION: BCH(78, 64) ---
n_mother, k_mother = 127, 113 # Uses GF(2^7)
target_data = 64
target_check = 14             # 64 + 14 = 78
total_width = 78

print(f"// Generated for {target_data}-bit Data / {target_check}-bit Check")

# 1. Setup Code
GF = galois.GF(2**5)
bch = galois.BCH(n_mother, k_mother)

# 2. Extract P Matrix from the SYSTEMATIC Generator Matrix G = [I | P]
# This ensures P matches the systematic encoding used in Verilog
G = bch.G # dimensions [k_mother, n_mother]
# We want the last 'target_check' columns of G (The Parity Part)
# And the last 'target_data' rows (The Data Part we are using)
# Note: galois G usually puts I on the left, P on the right.
# We slice the bottom-right corner.
P_slice = G[k_mother - target_data :, k_mother :]

# Convert to simple integer list for logic generation
P_integers = []
print("\n// 1. PASTE THIS INTO 'bch_dec_encoder' AND 'bch_dec_decoder' (Initial Block)")
print("initial begin")
for i in range(target_data):
    # Convert row to integer
    row_val = 0
    row_vec = P_slice[i]
    for bit in row_vec:
        row_val = (row_val << 1) | int(bit)

    P_integers.append(row_val)

    # Map to Verilog: P_matrix[0] is LSB of Data.
    # In galois, last row is usually LSB of data.
    # Let's verify standard order: P_slice[last] -> Data[0]
    v_index = target_data - 1 - i
    print(f"    P_matrix[{v_index}] = {target_check}'h{row_val:03x};")
print("end")

# 3. Generate Case Statement using MATHEMATICAL LOGIC (Not Library)
# This forces the case statement to match the P_matrix perfectly.
# Logic:
#   Error in Check Bit k  -> Syndrome = (1 << k)
#   Error in Data Bit m   -> Syndrome = P_matrix[m]
#   Double Error          -> Syndrome = Syn(A) ^ Syn(B)

# Re-map P_integers to match Verilog Array Indexing
P_map = {} # Index -> Value
for i in range(target_data):
    v_index = target_data - 1 - i
    P_map[v_index] = P_integers[i]

syndrome_cases = {} # Syn -> Action String

# SBU: Check Bits (Verilog indices 0..9)
for i in range(target_check):
    syn = (1 << i)
    syndrome_cases[syn] = f"error_pattern[{i}] = 1'b1; // Check Bit {i}"

# SBU: Data Bits (Verilog indices 10..25)
for i in range(target_data):
    syn = P_map[i]
    cw_idx = i + target_check
    syndrome_cases[syn] = f"error_pattern[{cw_idx}] = 1'b1; // Data Bit {i}"

# DBU: All Pairs
for i in range(total_width):
    for j in range(i + 1, total_width):
        # Get Syn for bit i
        if i < target_check: syn_i = (1 << i)
        else: syn_i = P_map[i - target_check]

        # Get Syn for bit j
        if j < target_check: syn_j = (1 << j)
        else: syn_j = P_map[j - target_check]

        total_syn = syn_i ^ syn_j

        if total_syn not in syndrome_cases:
            syndrome_cases[total_syn] = f"begin error_pattern[{i}] = 1'b1; error_pattern[{j}] = 1'b1; end"

print("\n// 2. PASTE THIS INTO 'bch_dec_decoder' (Case Statement)")
print("case (syndrome)")
for syn in sorted(syndrome_cases.keys()):
    print(f"    {target_check}'h{syn:03x}: {syndrome_cases[syn]}")
print("    default: double_error_o = 1'b1;")
print("endcase")