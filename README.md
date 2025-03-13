# Aria2-AutoMove

A small tool for aria2 to automatically move downloaded video files to the most appropriate destination path.

## Installation
```bash
git clone https://github.com/ulion/aria2-automove.git
cd aria2-automove
./setup.sh
```
The setup script will:
- Create a Python virtual environment
- Install required dependencies
- Setup aria2 configuration (optional)
- Create automove.conf from sample

After installation, edit `automove.conf` to set your OpenAI API key and target folder path.

## Usage
Typically we setup `aria2` to call `automove.py` when a download completes. The setup script will help you configure this automatically.

**Important Notes:** 
- Make sure automove.sh is accessible to the user running aria2. The aria2 user must have permission to access and execute the AutoMove scripts.
- Any target final directory must exist. The script will not create directories automatically and will skip moving files if no suitable target directory is matched by LLM.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.