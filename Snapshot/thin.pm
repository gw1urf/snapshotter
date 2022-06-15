# Variant for LVM thin snapshots

package Snapshot;

sub checkconfig
{
    my ($config) = @_;

    # Check the source is specified and split it up
    # for later use.
    die "\"source = \" should be of the form /dev/vgname/lvname\n"
        unless ($config->{source} =~ m#^/dev/([^/]+)/([^/]+)$#);
    $config->{vg} = $1;
    $config->{lv} = $2;
}

sub exists
{
    my ($location) = @_;
    my $pid = fork;

    die "fork: $!\n" unless defined($pid);
    if ($pid == 0)
    {
        close(STDOUT);
        close(STDERR);
        exec "lvdisplay", $location;
        die "exec: $!\n";
    }
    waitpid($pid, 0);
    return ($? ? 0 : 1);
}

sub newname
{
    my ($config) = @_;

    # Use the script start time, which is available in the
    # special variable, $^T
    my @t = gmtime($^T);

    return sprintf("%s-%04d%02d%02dT%02d%02d%02dZ", 
        $config->{lv}, $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0]);
}

sub snapshot
{
    my ($config, $name) = @_;

    &system_no_stderr("lvcreate", "-s", "-n", $name, $config->{source});
    return 0 if ($?);

    # By default, snapshots are skipped for auto-activation. I think we want them
    # to be activated for ease of use.
    &system_no_stderr("lvchange", "-k", "n", $config->{vg}."/".$name);
    return 0 if ($?);

    # Now activate and trim it.
    &system_no_stderr("lvchange", "-ay", $config->{vg}."/".$name);
    return 0 if ($?);

    return 1;
}

sub delete
{
    my ($config, $name) = @_;

    &system_no_stderr("lvremove", "-f", $config->{vg}."/".$name);

    return !$?;
}

# Get a list of existing snapshots for this config.
sub list
{
    my ($config) = @_;
    my @snaps = (); 

    my $pid = open(LVDISPLAY, "-|");
    die "fork: $!\n" unless defined($pid);
    if ($pid == 0)
    {
        # lvdisplay insists on scanning all DRBDs and warning if
        # not primary. Suppress stderr.
        close(STDERR);
        exec "lvdisplay", "-c";
        die "exec: $!\n";
    }
    while (<LVDISPLAY>)
    {
        s/^\s*//;
        my ($devname) = (split(":", $_))[0];
        next unless ($devname =~ m#/dev/$config->{vg}/($config->{lv}-(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)Z)#);
        my $stamp = Time::Local::timegm($7, $6, $5, $4, $3-1, $2-1900);
        push(@snaps, [$1, $stamp]);
    }
    close(LVDISPLAY);

    # Sort by time.
    @snaps = sort {$a->[1] <=> $b->[1]} @snaps;

    return \@snaps;
}

sub system_no_stderr
{
    my @cmd = @_;

    my $pid = fork;
    die "fork: $!\n" unless defined($pid);
    if ($pid == 0)
    {
        close(STDERR);
        exec @cmd;
        die "exec: $!\n";
    }
    waitpid($pid, 0);
    return $?;
}

1;
