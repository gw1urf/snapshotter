# Variant for ZFS

package Snapshot;

sub checkconfig
{
    return;
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
	    exec "zfs", "list", $location;
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

    return sprintf("%s\@%04d%02d%02dT%02d%02d%02dZ",
        $config->{source}, $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0]);
}

sub snapshot
{
    my ($config, $name) = @_;

    system "zfs", "snapshot", "-r", $name;
    return !$?;
}

sub delete
{
    my ($config, $name) = @_;

    system "zfs", "destroy", "-r", $name;
    return !$?;
}

# Get a list of existing snapshots for this config.
sub list
{
    my ($config) = @_;
    my @snaps = (); 

    my $pid = open(ZFS, "-|");
    die "fork: $!\n" unless defined($pid);
    if ($pid == 0)
    {
        exec "zfs", "list", "-Hrd1", "-t", "snapshot", "-o", "name", "-s", "name", $config->{source};
        die "exec: $!\n";
    }

    while (<ZFS>)
    {
        chop;
        s/^.*@//;

        # Only want snapshots with a datestamp.
        next unless (/^((\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)Z)$/);

        my $stamp = Time::Local::timegm($7, $6, $5, $4, $3-1, $2-1900);
        push(@snaps, [ $1, $stamp ]);
    }

    close(ZFS);

    # Sort by time.
    @snaps = sort {$a->[1] <=> $b->[1]} @snaps;

    return \@snaps;
}

1;
