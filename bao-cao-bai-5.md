# Báo cáo Bài 5: Vì sao Gradle mất cache trong Multi-stage CI/CD

Việc dùng self-hosted Runner không đồng nghĩa mọi tiến trình trong pipeline đều dùng chung filesystem của máy chủ. Nếu job chạy Gradle trực tiếp trên Runner, tiến trình thường chạy dưới cùng tài khoản hệ điều hành qua nhiều lần chạy. Khi đó, thư mục mặc định `~/.gradle` nằm trên ổ đĩa bền vững của máy Runner, nên dependency đã tải có thể được tái sử dụng.

Với Docker-outside-of-Docker (DooD), Docker CLI trong job kết nối tới daemon qua socket `/var/run/docker.sock`. Socket chỉ cung cấp kênh điều khiển daemon; nó không chia sẻ thư mục home của host vào container. Khi Dockerfile bắt đầu stage `builder`, daemon tạo môi trường build riêng từ image JDK. Lệnh `RUN ./gradlew bootJar` và Gradle chạy bên trong môi trường đó, với `GRADLE_USER_HOME` mặc định thuộc filesystem của container (thường là `/root/.gradle`), không phải `~/.gradle` của tài khoản Runner trên host.

Vì vậy, cache Gradle trên host không tự được nhìn thấy trong builder. Các file sinh ra trong filesystem của stage cũng không tự trở thành thư mục cache dùng chung giữa những container build độc lập. Docker có cơ chế cache layer riêng, nhưng đó không đồng nghĩa với việc Gradle dùng lại cache host; thay đổi ở các bước trước có thể khiến bước build phải chạy lại và tải dependency. Điều này giải thích vì sao thời gian tăng lên dù Runner vẫn là self-hosted và Docker daemon vẫn chạy trên máy đó.

Kết luận: DooD chia sẻ quyền điều khiển Docker daemon, không chia sẻ toàn bộ filesystem. Muốn dùng cache xuyên lần build cần cấu hình cache bền vững riêng cho BuildKit/Gradle; chỉ mount Docker socket là chưa đủ.
