using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;

// 回环黑洞服务：监听 127.0.0.1:443，接受连接后立即关闭。
// 用途：hosts 里被屏蔽的域名解析到 127.0.0.1 后，连接能在毫秒级
// 收到错误返回，而不是挂在 SYN 超时上（实测约 71ms vs 2~20 秒）。
class Blackhole
{
    static void Main()
    {
        var listener = new TcpListener(IPAddress.Loopback, 443);
        try { listener.Start(256); }
        catch { return; } // 端口已被占用：静默退出，不影响系统
        while (true)
        {
            try
            {
                var client = listener.AcceptTcpClient();
                ThreadPool.QueueUserWorkItem(_ =>
                {
                    try
                    {
                        client.LingerState = new LingerOption(true, 0); // 关闭即重置
                        client.Close();
                    }
                    catch { }
                });
            }
            catch { }
        }
    }
}
