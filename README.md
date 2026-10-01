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

## Bài 2: Multi-stage build cho cart-service

`Dockerfile.cart-service` dùng JDK 17 ở stage `builder` để chạy `./gradlew bootJar`, sau đó
chỉ chuyển executable JAR sang stage `runtime` dùng JRE 17. Nhờ vậy image cuối
không chứa JDK, Gradle cache hay mã nguồn thô. Lệnh `COPY --from=builder` lấy
artifact từ stage build; `*-plain.jar` được loại khỏi lựa chọn vì không phải
executable Spring Boot JAR.

Đặt Dockerfile cùng thư mục với `gradlew`, `settings.gradle[.kts]` và mã nguồn
`cart-service`, rồi chạy trên máy có Docker:

```sh
docker build --file Dockerfile.cart-service --target builder -t cart-service:builder .
docker build --file Dockerfile.cart-service --target runtime -t cart-service:runtime .
docker image ls cart-service --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
```

So sánh size của `builder` và `runtime` trong kết quả. Size thực tế tùy thuộc
ứng dụng và nền tảng nên cần đo trên chính máy build; workspace bài tập hiện
chưa có source Gradle/`gradlew`, vì vậy chưa thể tạo image `cart-service` hay
báo số MB trung thực ở đây.

Workflow DooD của Bài 1 tiếp tục dùng `Dockerfile.dood` riêng, không phụ thuộc
source Gradle và không bị ảnh hưởng bởi Dockerfile multi-stage.

## Bài 6: Build, push và verify delivery-service

`Dockerfile` build Java 17 ở stage JDK, sau đó chỉ đưa bytecode vào stage JRE
17 chạy bằng user không phải root. Service mẫu cung cấp endpoint `/health` để
workflow kiểm tra container sau khi pull image từ GHCR.

Workflow `.github/workflows/main.yml` chạy tuần tự trên mỗi push: checkout,
chuẩn hóa owner thành chữ thường, build image, đăng nhập GHCR bằng
`GITHUB_TOKEN`, push tag commit SHA và `latest`, pull lại tag SHA, rồi chạy
container detached và chờ `/health` trả `200 OK`. Quyền `packages: write` cấp
đủ quyền publish; không cần PAT cá nhân.

Sau khi push workflow, xem **Actions → Build, push, and verify delivery-service**.
Image được đăng dưới `ghcr.io/<owner-lowercase>/delivery-service`, với tag commit
SHA và `latest`. Nếu package private không cho workflow truy cập, bật quyền
Actions cho repository trong **Package settings → Manage Actions access**.

## Bài 3: Build và push payment-service lên GHCR

GHCR image dùng tên dạng `ghcr.io/<github-username-lowercase>/payment-service:1.0.0`.
Tạo **Personal access token (classic)** tại **GitHub → Settings → Developer
settings → Personal access tokens → Tokens (classic)** và chỉ cấp `write:packages`
để push. Chỉ thêm `read:packages` nếu cần pull package private; không cấp
`delete:packages` cho bài này. Nếu tài khoản bật SSO, authorize token cho SSO.
Không nhập mật khẩu GitHub hoặc ghi PAT trực tiếp vào lệnh/script.

Đặt mã nguồn và Dockerfile thật của `payment-service` trong workspace. Từ Git
Bash/WSL, chạy script; PAT được hỏi ẩn và truyền qua `--password-stdin`:

```sh
bash scripts/publish-payment-service.sh payment-service/Dockerfile payment-service
```

Script dừng nếu Dockerfile hoặc build context không tồn tại. Khi build/push xong,
xác minh tag local và mở **GitHub profile → Packages**:

```sh
docker image inspect ghcr.io/your-lowercase-username/payment-service:1.0.0
```

Thay đường dẫn mẫu bằng username GitHub viết thường của bạn. Workspace bài tập
hiện chưa có source/Dockerfile `payment-service` và mình không có PAT của bạn,
nên chưa thể thực hiện publish thật hoặc xác nhận package đã hiện trên profile.

Tài liệu tham khảo:

- [GitHub: Working with the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker: `docker login`](https://docs.docker.com/reference/cli/docker/login/)
- [Docker: `docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/)
- [Docker: `docker image push`](https://docs.docker.com/reference/cli/docker/image/push/)

## Bài 4: Pull và verify image trong GitHub Actions

Workflow `.github/workflows/ci.yml` đăng nhập bằng actor hiện tại và
`secrets.GITHUB_TOKEN`, chỉ cấp `packages: read`, chuyển toàn bộ image reference
sang chữ thường, pull `payment-service:1.0.0`, rồi chạy container detached để
xác nhận container còn ở trạng thái running. Workflow chỉ pull image, không
build lại source.

Đảm bảo package `payment-service` đã được push theo đúng owner hiện tại và tag
`1.0.0`. Nếu pull trả về `denied`, vào trang package trên GHCR → **Package
settings → Manage Actions access**, cấp repository này quyền **Read**. Sau đó
push commit hoặc chọn **Actions → Pull and verify GHCR image → Run workflow**.
Thời gian thực tế phụ thuộc kích thước image và cache/network của runner; lần
pull đầu tiên không được đảm bảo dưới 20 giây.

## Tài liệu tham khảo

- [Docker: Bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)
- [Docker: Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [GitHub: Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [Runner image documentation](https://github.com/myoung34/docker-github-actions-runner)
