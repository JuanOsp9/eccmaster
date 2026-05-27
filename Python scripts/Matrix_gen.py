import galois
import numpy as np

# --- CONFIGURATION ---
data_bits = 16         # Change to 16, 32, or 64
# ---------------------

# Defines for standard BCH codes
if data_bits == 16:
    n_mother, k_mother = 31, 21
    target_data = 16
    target_check = 10 # n=26
elif data_bits == 32:
    n_mother, k_mother = 63, 51
    target_data = 32
    target_check = 12 # n=44
elif data_bits == 64:
    n_mother, k_mother = 127, 113
    target_data = 64
    target_check = 14 # n=78

print(f"Generating Parity Matrix for Data={target_data}, Check={target_check}...")

# 1. Create the Mother Code Generator Matrix (G)
# G is typically returned as [I | P] or [P | I]. We need to ensure [I | P] form.
GF = galois.GF(2**(n_mother.bit_length() - 1))
bch = galois.BCH(n_mother, k_mother)
G_mother = bch.G # Shape (k_mother, n_mother)

# 2. Extract the Parity Part (P)
# galois.BCH usually creates systematic codes where G = [I | P]
# (Identity on the left, Parity on the right).
# Let's verify and extract P.
# We assume the columns k_mother to n_mother-1 are the parity columns.
P_mother = G_mother[:, k_mother:] # Shape (k_mother, r)

# 3. Shorten the Matrix
# We have 'k_mother' rows, but we only have 'target_data' bits.
# Shortening usually implies the "top" (first) bits are zero.
# So we keep the BOTTOM 'target_data' rows of the matrix.
rows_to_remove = k_mother - target_data
P_short = P_mother[rows_to_remove:, :] # Shape (target_data, target_check)

# 4. Generate Verilog Output
print("\n// --- COPY THIS INTO YOUR MODULE ---")
print(f"// Parity Matrix assignments for Data Width {target_data}")
print("initial begin")

for i in range(target_data):
    # Convert the row of 0s and 1s into an integer
    row_val = 0
    row_array = P_short[i, :] # Row i contains connections for Data Bit i

    for bit in row_array:
        row_val = (row_val << 1) | int(bit)

    # Verilog Indexing: P_matrix[0] corresponds to Data Bit 0 (LSB)
    # Python Matrix Indexing: Row 0 is usually MSB in poly arithmetic.
    # To match standard little-endian Verilog (Data[0]), we often read from the bottom up
    # or match the specific systematic layout.
    # For BCH, standard "High Order = Row 0".
    # If your Verilog data_i[0] is the LSB, we should map the Last Row of P to P_matrix[0].

    verilog_index = target_data - 1 - i
    print(f"    P_matrix[{verilog_index}] = {target_check}'h{row_val:03x};")

print("end")
print("// ----------------------------------")