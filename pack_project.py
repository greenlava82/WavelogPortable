import os

def pack_flutter_project(output_file="full_code_dump.txt"):
    # The folders we care about
    target_dir = "lib"
    
    with open(output_file, "w", encoding="utf-8") as outfile:
        outfile.write("CURRENT PROJECT STATE:\n")
        outfile.write("======================\n\n")
        
        # Walk through the lib directory
        for root, dirs, files in os.walk(target_dir):
            for file in files:
                if file.endswith(".dart"):
                    file_path = os.path.join(root, file)
                    
                    # Write a header so I know which file is which
                    outfile.write(f"// FILE: {file_path}\n")
                    outfile.write("// " + "="*30 + "\n")
                    
                    try:
                        with open(file_path, "r", encoding="utf-8") as infile:
                            outfile.write(infile.read())
                    except Exception as e:
                        outfile.write(f"// Error reading file: {e}")
                        
                    outfile.write("\n\n") # Formatting space
                    
    print(f"✅ Project packed into '{output_file}'")
    print("Copy the contents of that file and paste it to Gemini to restore context!")

if __name__ == "__main__":
    pack_flutter_project()