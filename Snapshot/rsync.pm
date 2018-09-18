# Variant for rsync with link-dest

package Snapshot;

use File::Path;

sub checkconfig
{
    my ($config) = @_;
    die "Rsync config must have a \"dest = \" specified\n"
        unless (defined($config->{dest}));
}

sub exists
{
    my ($location) = @_;
    return (-d $location);
}

sub newname
{
    my ($config) = @_;

    # Use the script start time, which is available in the
    # special variable, $^T
    my @t = localtime($^T);

    return sprintf("%s/%04d%02d%02d-%02d%02d%02d",
        defined($config->{dest}) ? $config->{dest} : $config->{source}, 
            $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0]);
}

sub snapshot
{
    my ($config, $name) = @_;

    system "rsync", "-av", "--delete", "--link-dest=$config->{dest}/current", $config->{source}."/", $name."/";
    return 0 if ($?);

    unlink("$config->{dest}/current");

    if (!symlink($name, "$config->{dest}/current"))
    {
        warn "symlink($name, $config->{dest}/current): $!\n";
        return 0;
    }

    return 1;
}

sub delete
{
    my ($config, $name) = @_;

    system "rm", "-rf", $name;

    return !$?;
}

# Get a list of existing snapshots for this config.
sub list
{
    my ($config) = @_;
    my @snaps = (); 

    my $dest = (defined($config->{dest}) ? $config->{dest} : $config->{source});
    opendir(D, $dest) || die "Failed to open $dest: $!\n";
    foreach my $sub (readdir(D))
    {
        if (($sub =~ /^((\d\d\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d))$/) && (-d "$dest/$sub"))
        {
            my $stamp = Time::Local::timelocal($7, $6, $5, $4, $3-1, $2-1900);
            push(@snaps, [ $1, $stamp ]);
        }
    }

    # Sort by time.
    @snaps = sort {$a->[1] <=> $b->[1]} @snaps;

    return \@snaps;
}

1;
