package Greenend::ViewGCOV::FileContents;
use warnings;
use strict;
use Gtk2;

our %color = (

  "notExecutableBackground" => "#ffffff",
  "notExecutableForeground" => "#808080",

  "notExecutedBackground" => "#ffa0a0",
  "notExecutedForeground" => "#000000",

  "executedBackground" => "#ffffff",
  "executedForeground" => "#000000",

  "notExecutedFunctionBackground" => "#ff6060",
  "notExecutedFunctionForeground" => "#000000",

  "executedFunctionBackground" => "#a0ffa0",
  "executedFunctionForeground" => "#000000",

);
# TODO above should be configurable

# new FileContents()
sub new {
    my $self = bless {}, shift;
    return $self->initialize(@_);
}

# initialize()
sub initialize {
    my $self = shift;
    $self->{model} = new Gtk2::ListStore('Glib::Int', # line number
                                         'Glib::String', # times executed
                                         'Glib::String', # program text
                                         'Glib::String', # cell-background
                                         'Glib::String'); # foreground
    $self->{view} = new Gtk2::TreeView($self->{model});
    my $lineRenderer = new Gtk2::CellRendererText();
    $lineRenderer->set("xalign", 1);
    my $lineno = Gtk2::TreeViewColumn->new_with_attributes
        ("Line", $lineRenderer,
         'text' => 0,
         'cell-background' => 3,
         'foreground' => 4);
    $lineno->set_resizable(1);
    my $executedRenderer = new Gtk2::CellRendererText();
    $executedRenderer->set("xalign", 1);
    my $executed = Gtk2::TreeViewColumn->new_with_attributes
        ("Count", $executedRenderer,
         'text' => 1,
         'cell-background' => 3,
         'foreground' => 4);
    $executed->set_resizable(1);
    my $textRenderer = new Gtk2::CellRendererText();
    $textRenderer->set("family", "Monospace");
    my $text = Gtk2::TreeViewColumn->new_with_attributes
        ("Code", $textRenderer,
         'text' => 2,
         'cell-background' => 3,
         'foreground' => 4);
    $text->set_resizable(1);
    $self->{view}->append_column($lineno);
    $self->{view}->append_column($executed);
    $self->{view}->append_column($text);
    $self->{view}->set_size_request(720, 600);
    $self->{view}->signal_connect
        ('button-press-event',
         sub { $self->buttonPressed(@_); });
    $self->{view}->signal_connect
        ('leave-notify-event',
         sub { $self->left(@_); });
    $self->{view}->signal_connect
        ('enter-notify-event',
         sub { $self->motion(@_); });
    $self->{view}->signal_connect
        ('motion-notify-event',
         sub { $self->motion(@_); });
    $self->{view}->signal_connect
        ('realize',
         sub { 
             my $gdkwindow = $self->{view}->get_parent_window();
             my $eventmask = $gdkwindow->get_events();
             $eventmask |= [ 'pointer-motion-mask' ];
             $eventmask |= [ 'leave-notify-mask' ];
             $eventmask |= [ 'enter-notify-mask' ];
         });
    $self->{scrolled} = new Gtk2::ScrolledWindow();
    $self->{scrolled}->set_policy('automatic', 'automatic');
    $self->{scrolled}->add($self->{view});
    $self->{scrolled}->get_vadjustment()->signal_connect
        ("value-changed",
         sub { $self->scrolled(@_); });
    return $self;
}

# setFiles(FILEFILES)
#
# The list of files
sub setFiles($$) {
    my $self = shift;
    $self->{files} = shift;
}

# Return the widget to display
sub widget($) {
    my $self = shift;
    return $self->{scrolled};
}

# Called when the pointer leaves the window
# (and at othre times to destroy the info hover)
sub left($$$) {
    my ($self, $widget, $event) = @_;
    if(exists $self->{info}) {
        $self->{info}->destroy();
        delete $self->{info};
        delete $self->{infoLine};
    }
}

# Called when the pointer moves within the window, or when it enters
# the window.
sub motion($$$) {
    my ($self, $widget, $event) = @_;
    my $path = $self->{view}->get_path_at_pos($event->x(), $event->y());
    my $display = 0;
    if(defined $path) {
        my @path = $path->get_indices();
        my $line = $path[0] + 1;
        # May need to reconsistute the info hover either if it does not
        # exist or if it exists but refers to some other line
        if(!exists $self->{info} or $self->{infoLine} != $line) {
            # Zap existing data
            $self->left($widget, $event);
            # Create the hover
            $self->{info} = new Gtk2::Window('popup');
            $self->{info}->set_type_hint('tooltip');
            $self->{info}->set_keep_above(1);
            $self->{infoLine} = $line;
            $self->{infobuffer} = new Gtk2::TextBuffer();
            $self->{infobuffer}->create_tag("red",
                                            "foreground", "red");
            my $infoview = Gtk2::TextView->new_with_buffer($self->{infobuffer});
            my $frame = new Gtk2::Frame();
            $frame->add($infoview);
            $frame->show_all();
            $self->{info}->add($frame);
            $self->{infobuffer}->delete($self->{infobuffer}->get_bounds());
            # Populate it
            my $af = $self->{files}->getFile($self->{current});
            my $function = $af->functionInfo($line);
            my $branch = $af->branchInfo($line);
            if(defined $function) {
                for my $n (0 .. @$function - 1) {
                    $self->{infobuffer}->insert
                        ($self->{infobuffer}->get_end_iter(),
                         "\n") if $display;
                    my $f = $function->[$n];
                    my $s = sprintf("Function %s\n  Called %d times returned %d%%\n  %d%% of blocks executed",
                                    $self->demangle($f->{name}),
                                    $f->{called},
                                    $f->{returned},
                                    $f->{blocks});
                    if($f->{called}) {
                        $self->{infobuffer}->insert
                            ($self->{infobuffer}->get_end_iter(),
                             $s);
                    } else {
                        $self->{infobuffer}->insert_with_tags_by_name
                            ($self->{infobuffer}->get_end_iter(),
                             $s,
                             "red");
                    }
                    $display = 1;
                }
            }
            if(defined $branch) {
                for my $n (0 .. @$branch - 1) {
                    $self->{infobuffer}->insert
                        ($self->{infobuffer}->get_end_iter(),
                         "\n") if $display;
                    my $b = $branch->[$n];
                    my ($action, $type, $never);
                    if($b->{type} eq 'call') {
                        $type = "Call";
                        $action = "returned";
                        $never = "executed";
                    } elsif($b->{type} eq 'branch') {
                        $type = "Branch";
                        $action = "taken";
                        $never = "taken";
                    }
                    if(defined $action) {
                        if($b->{count} > 0) {
                            my $s = "$type $action $b->{count}%";
                            $self->{infobuffer}->insert
                                ($self->{infobuffer}->get_end_iter(),
                                 $s);
                        } else {
                            my $s = "$type never $never";
                            $self->{infobuffer}->insert_with_tags_by_name
                                ($self->{infobuffer}->get_end_iter(),
                                 $s,
                                 "red");
                        }
                        $display = 1;
                    }
                }
            }
        } else {
            $display = exists $self->{info};
        }
    }
    if($display) {
        $self->{info}->move($event->x_root() + 8, $event->y_root() + 8);
        $self->{info}->present();
    } else {
        $self->left($widget, $event);
    }
}

# Called when the window is scrolled
sub scrolled($$$) {
    my ($self) = @_;
    # TODO we should figure out what we're looking at and update the
    # info window accordingly.
    $self->left(undef, undef);
}

# Called when a button is pressed
sub buttonPressed($$$) {
    my ($self, $widget, $event) = @_;
    if($event->type() eq 'button-press'
       and $event->button() == 1) {
        return 1;
    }
    if($event->type() eq 'button-press'
       and $event->button() == 3) {
        $self->{files}->contextMenu($event, $self->{current})
            if defined $self->{current};
        return 1;
    }
}

# select(PATH)
#
# Select the file to display
sub select($$) {
    my ($self, $path) = @_;
    if(defined $self->{current}) {
        return if defined $path and $path eq $self->{current};
        my ($s, $e) = $self->{view}->get_visible_range();
        my @s = $s->get_indices();
        $self->{position}->{$self->{current}} = $s[0];
    }
    $self->{current} = $path;
    return $self->redraw();
}

# Display nothing
sub clear($) {
    my $self = shift;
    if(defined $self->{current}) {
        delete $self->{position}->{$self->{current}};
        delete $self->{current};
    }
    return $self->redraw();
}

sub state($$) {
    my $self = shift;
    my $n = shift;
    my $af = $self->{files}->getFile($self->{current});
    my $count = $af->lineExecutionCount($n);
    my $function = $af->functionInfo($n);
    if(defined $function) {
        my $called = 0;
        for my $f (@$function) {
            if($f->{called} > 0) {
                $called = 1;
                last;
            }
        }
        if($called) {
            return 'executedFunction';
        } else {
            return 'notExecutedFunction';
        }
    } elsif($count < 0) {
        return 'notExecutable';
    } elsif($count == 0) {
        return 'notExecuted';
    } else {
        return 'executed';
    }
}

# Force redraw
sub redraw($) {
    my $self = shift;
    $self->{model}->clear();
    return unless defined $self->{current};
    my $af = $self->{files}->getFile($self->{current});
    my $where = $self->{position}->{$self->{current}};
    for my $n (1 .. $af->linesTotal()) {
        my $count = $af->lineExecutionCount($n);
        my $text = $af->lineText($n);
        $where = $n - ($n != 1) - 1 if $count == 0 and !defined $where;
        my $state = $self->state($n);
        if($state eq 'notExecutable' && $n > 1 && $n < $af->linesTotal()) {
            # A non-executable line between two not-executed lines is
            # colored as the latter, to reduce distracting stripiness.
            my $before = $self->state($n - 1);
            my $after = $self->state($n + 1);
            if($before eq $after
               && $before eq 'notExecuted') {
                $state = $before;
            }
        }
        $self->{model}->set($self->{model}->append(),
                            0, $n,
                            1, $count < 0 ? "-" : $count,
                            2, $text,
                            3, $color{"${state}Background"},
                            4, $color{"${state}Foreground"});
    }
    $self->{view}->scroll_to_cell(Gtk2::TreePath->new_from_indices($where))
        if defined $where;
    return $self;
}

sub demangle($$) {
    my $self = shift;
    my $mangled = shift;
    if(!exists $self->{demangle}->{$mangled}) {
        my $demangled = `echo \Q$mangled\E | c++filt`;
        if($? == 0) {
            chomp $demangled;
            $self->{demangle}->{$mangled} = $demangled;
        } else {
            $self->{demangle}->{$mangled} = $mangled;
        }
    }
    return $self->{demangle}->{$mangled};
}

1;
