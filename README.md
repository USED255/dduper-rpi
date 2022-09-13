# dduper-rpi
wrtyis@outlook.com

在运行先首先你要知道: dduper 已经在 btrfs 文档找不到了, 然后这是个 laks/dduper 的树莓派改版, 最后你要知道微软的重复数据删除可以在1.5t的数据上可以帮我节省300g而积极开发的 duperemove 在4t数据上只能帮我节省50g, dduper 非常吃内存, 确保内存充足, Dockerfile 找同名 Github 仓库.
 ```
docker run -it --rm --privileged -v /media:/media used255/dduper-rpi:latest --device /dev/sda1 --dir /media --recurse --verbose
```
