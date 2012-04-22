package Greenend::ViewGCOV::AnnotatedFile;
use warnings;
use strict;
use IO::File;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self->initialize(@_);
}

# Lazy initialization
sub initialize($$) {
    my $self = shift;
    $self->{path} = shift;
    delete $self->{lines};
    delete $self->{additional};
    return $self;
}

# Return total number of lines
sub linesTotal($) {
    my $self = shift;
    $self->parse() unless defined $self->{lines};
    return scalar @{$self->{lines}};
}

# Return number of lines that are executable
sub linesExecutable($) {
    my $self = shift;
    $self->parse() unless defined $self->{lines};
    return $self->{executable};
}

# Return number of lines executed at least ones
sub linesExecuted($) {
    my $self = shift;
    $self->parse() unless defined $self->{lines};
    return $self->{executed};
}

# Return proportion of executable lines executed
# Returns 1 if there are no executable lines
sub linesExecutedProportion($) {
    my $self = shift;
    $self->parse() unless defined $self->{lines};
    if($self->{executable}) {
        return $self->{executed} / $self->{executable};
    } else {
        return 1;
    }
}

# Return text of a line.  First line is line 1.
sub lineText($$) {
    my $self = shift;
    my $n = shift;
    $self->parse() unless defined $self->{lines};
    return $self->{lines}->[$n - 1]->{text};
}

# Return execution count for a line.
# -1 means it's not executable.
sub lineExecutionCount($$) {
    my $self = shift;
    my $n = shift;
    $self->parse() unless defined $self->{lines};
    return $self->{lines}->[$n - 1]->{count};
}

# functionInfo(LINENO, KEY)
#
# Return function information.  KEY can be name, called, returned, blocks.
sub functionInfo($$$) {
    my ($self, $n, $key) = @_;
    $self->parse() unless defined $self->{lines};
    if(exists $self->{lines}->[$n - 1]->{function}) {
        return $self->{lines}->[$n - 1]->{function}->{$key};
    } else {
        return undef;
    }
}

sub sourcePath($) {
    my $self = shift;
    $self->parse() unless defined $self->{lines};
    my $source = $self->{additional}->{Source};
    return $self->{path} if !defined $source;
    if($source !~ m,/,) {
        if($self->{path} =~ m,^(.*)/([^/]+)$,) {
            $source = "$1/$source";
        }
    }
    if($source =~ m,^\./(.*),) {
        $source = $1;
    }
    return $source;
}

sub parse($) {
    my $self = shift;
    # Parse the .gcov file
    my $input = new IO::File($self->{path}, "r");
    die "opening $self->{path}: $!\n" unless defined $input;
    my $line;
    while(defined($line = $input->getline())) {
        chomp $line;
        $self->parseLine($line);
    }
    die "reading $self->{path}: $!\n" if $input->error();
    $input->close();
    # Compute whole-file statistics
    my $executable = 0;
    my $executed = 0;
    for my $line (@{$self->{lines}}) {
        my $count = $line->{count};
        if($count >= 0) {
            ++$executable;
        }
        if($count > 0) {
            ++$executed;
        }
    }
    $self->{executable} = $executable;
    $self->{executed} = $executed;
    return $self;
}

sub parseLine($$) {
    my $self = shift;
    local $_ = shift;
       if(/^ *-: *0:([^:]+):(.*)/) { $self->{additional}->{$1} = $2; }
    elsif(/^ *-: *(\d+):(.*)/)     { $self->textLine(-1,$1,$2); }
    elsif(/^ *(\d+): *(\d+):(.*)/) { $self->textLine($1,$2,$3); }
    elsif(/^ *#*: *(\d+):(.*)/)    { $self->textLine(0,$1,$2); }
    elsif(/^function (\S+) called (\d+) returned (\d+)% blocks executed (\d+)%/) {
        push(@{$self->{function}}, {
            "name" => $1,
            "called" => $2,
            "returned" => $3,
            "blocks" => $4
        });
    }
    # TODO extra annotations
}

sub textLine($$$$) {
    my ($self, $count, $number, $text) = @_;
    my $line = {
        "text" => $text,
        "count" => $count
    };
    if(exists $self->{function}) {
        $line->{function} = $self->{function}->[0];
        delete $self->{function};
    }
    push(@{$self->{lines}}, $line);
}

1;
