import os

def count_files(directory):
    if not os.path.exists(directory):
        return -1 # 表示目录不存在
    
    count = 0
    # 只计算文件，不计算子目录，忽略 .DS_Store
    try:
        # 只列出当前目录下的文件，不递归计算子目录的内容，因为子目录会被当作独立的条目处理
        for item in os.listdir(directory):
            item_path = os.path.join(directory, item)
            if os.path.isfile(item_path) and not item.startswith('.'):
                count += 1
    except OSError as e:
        print(f"Error reading {directory}: {e}")
        return -1
    return count

def verify_counts():
    base_dir = "wallpaper/desktop"
    preview_base = "preview/desktop"
    thumb_base = "thumbnail/desktop"

    if not os.path.exists(base_dir):
        print(f"Error: Base directory {base_dir} does not exist.")
        return

    print(f"{'Path':<50} | {'Orig':<5} | {'Prev':<5} | {'Thumb':<5} | {'Status'}")
    print("-" * 90)

    mismatch_found = False

    # 遍历 base_dir 下的所有目录
    for root, dirs, files in os.walk(base_dir):
        # 计算相对路径
        rel_path = os.path.relpath(root, base_dir)
        if rel_path == ".":
            rel_path = ""
            
        # 构造对应的 preview 和 thumbnail 路径
        preview_path = os.path.join(preview_base, rel_path)
        thumb_path = os.path.join(thumb_base, rel_path)

        # 计算文件数量
        orig_count = count_files(root)
        
        # 如果原图文件夹里没有有效文件（可能只是包含子文件夹的父级目录），我们通常可以跳过，
        # 除非它是最底层目录。但为了全面，我们看是否有文件。
        # 如果 orig_count 为 0，且只有子目录，可能不需要对比文件数。
        # 但如果 preview 或 thumbnail 里有文件而 orig 没有，也是问题。
        
        preview_count = count_files(preview_path)
        thumb_count = count_files(thumb_path)

        # 只要有任何一个目录包含文件，就进行对比
        if orig_count > 0 or preview_count > 0 or thumb_count > 0:
            status = "OK"
            if orig_count != preview_count or orig_count != thumb_count:
                status = "MISMATCH"
                mismatch_found = True
            elif preview_count == -1 or thumb_count == -1:
                status = "MISSING DIR"
                mismatch_found = True
            
            if status != "OK":
                # 只打印有问题的或者是叶子节点的
                print(f"{rel_path:<50} | {orig_count:<5} | {preview_count:<5} | {thumb_count:<5} | {status}")

    if not mismatch_found:
        print("\nAll directories match perfectly!")
    else:
        print("\nFound discrepancies in the directories listed above.")

if __name__ == "__main__":
    verify_counts()
