# .factory/evals

Every executable regular file in this directory runs in gate 2 (`eval.sh`), in name order, with the change name as `$1` and the product repo as the working directory. Exit non-zero to block the change. A file that is not executable is skipped, so ship checks disabled and `chmod +x` to enable them.
