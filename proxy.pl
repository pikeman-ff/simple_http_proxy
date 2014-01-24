#!env perl
use AnyEvent::Socket;
use AnyEvent::Handle;
use Data::Dumper;
use LWP;
my $cv = AnyEvent->condvar;

my $clients={};
my $forwords={};
sub proxy_get_cb
{
    my ($fh,$lines,$req_handle) = @_;
    my $f_hdl = new AnyEvent::Handle
                    fh => $fh,
                    no_delay => 1,
                    on_eof => sub {
                        my $hdl=shift;
                        delete $forwards->{$hdl->fh->fileno};
                        $hdl->destroy;
                    },
                    on_error => sub {
                        my $hdl=shift;
                        delete $forwards->{$hdl->fh->fileno};
                        $hdl->destroy;
                    };
                $forwards->{fileno($fh)} = $f_hdl;
                $f_hdl->push_write($lines."\r\n\r\n");
                $f_hdl->on_read(sub{
                        my ($handle) = @_;
                        $req_handle->push_write($handle->{rbuf});
                        $handle->{rbuf}=undef;
                    });
}
sub get_req
{
        my ($hdl,$lines) = @_;
        my @headers = split /[\r\n]+/,$lines;
        my ($method,$url) = ($headers[0] =~ m{(\w+)\s+([^\s]+)\s});
        print "method = $method,url=$url\n";
        my $port = 80;
        if ( my ($host) = ($url =~ m{http://([^/]+)}i) ) {
            ($host,$port) = split /:/,$host;
            $port = 80 unless $port;
            $headers[0] =~ s{http://[^/]+}{};
            #print "host:$host,port=$port\n";
            #proxy_get($host,$port,$hdl);
        tcp_connect $host,$port,sub {
            my $fh = shift;
            my $h=join("\r\n",@headers);
            proxy_get_cb($fh,$h,$hdl);
        };

            #wait for next req
            $hdl->push_read(line=>"\r\n\r\n",\&get_req);
        } else {
            syswrite $hdl->fh,"HTTP/1.0 200\r\nServer: mini_http\r\nContent-Length:5\r\n\r\ndone\n";
            delete $clients->{fileno($fh)};
            $hdl->destroy;
        }
}
tcp_server undef,7070,sub {
    my ($fh, $host, $port) = @_;
    print "client is from:$host:$port\n";
    my  $hdl = new AnyEvent::Handle
        fh => $fh,
        no_delay => 1,
        timeout =>5,
        on_error => sub {
            print STDERR "client disconnect for error\n";
            my $hdl=shift;
            delete $clients->{$hdl->fh->fileno};
            $hdl->destroy;
        },
        on_eof => sub {
            print STDERR "client disconnect\n";
            my $hdl=shift;
            delete $clients->{$hdl->fh->fileno};
            $hdl->destroy;
        };
    $hdl->push_read( line => "\r\n\r\n", \&get_req);
    $clients->{fileno($fh)}=$hdl;
};
$cv->recv;
