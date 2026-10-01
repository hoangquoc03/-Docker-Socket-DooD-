# QuickBite: Docker-outside-of-Docker (DooD)

## Vì sao lỗi xảy ra

`docker build` trong job gọi Docker daemon qua Unix socket mặc định
`/var/run/docker.sock`. Runner chạy trong container nên không tự nhìn thấy socket
của host. Nếu socket không được bind-mount vào đúng đường dẫn trong container,
Docker CLI báo `Cannot connect to the Docker daemon`.

Trong `docker-compose.yml`, `source` là đường dẫn vật lý trên Linux host chạy
Docker daemon; `target` là đường dẫn nhìn thấy bên trong container Runner. Cả hai
đều là `/var/run/docker.sock`. Đây là bind mount, không phải named volume. Không
cần `privileged: true` cho Docker-outside-of-Docker.

## Cấu hình và khởi chạy trên Linux host

1. Cài Docker Engine/Compose plugin và xác nhận `sudo test -S /var/run/docker.sock`
   thành công trên host. Đường dẫn này là của Linux host, không phải máy Windows
   đang mở workspace.
2. Sao chép `.env.example` thành `.env`, điền URL repo và GitHub token có quyền
   đăng ký self-hosted runner cho repo. Với fine-grained PAT, cấp quyền
   **Repository permissions → Administration: Read and write** cho đúng repo.
   Không commit `.env` hoặc chia sẻ token.
3. Khởi chạy trong thư mục chứa compose:

   ```sh
   chmod 600 .env
   docker compose pull
   docker compose up -d
   docker compose logs -f runner
   ```

4. Trong GitHub repo, mở **Settings → Actions → Runners** và đợi runner
   `quickbite-dood-runner` hiện **Idle**. Runner có label `dood`.
5. Đưa các file này lên repository đó rồi push commit. Workflow
   `.github/workflows/dood-smoke-test.yml` chạy `docker info`, build image và
   chạy container smoke test.
6. Chụp màn hình trang **Actions → DooD smoke test → job docker-smoke-test** khi
   cả ba bước Docker đều thành công để nộp bằng chứng.

## Lưu ý bảo mật

Ai điều khiển được Docker socket thường có quyền tương đương root trên host.
Chỉ dùng runner này cho repository và workflow đáng tin cậy; không cho workflow
từ pull request không tin cậy truy cập runner. Compose mount socket ở chế độ
read-write vì build cần điều khiển daemon.

## Tài liệu tham khảo

- [Docker: Bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)
- [GitHub: Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [Runner image documentation](https://github.com/myoung34/docker-github-actions-runner)
