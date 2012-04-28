package Greenend::ViewGCOV::FileContents;
use warnings;
use strict;
use Gtk2;

our $notExecutableBackground = "#ffffff";
our $notExecutableForeground = "#808080";

our $notExecutedBackground = "#ffa0a0";
our $notExecutedForeground = "#000000";

our $executedBackground = "#ffffff";
our $executedForeground = "#000000";

our $notExecutedFunctionBackground = "#ff6060";
our $notExecutedFunctionForeground = "#000000";

our $executedFunctionBackground = "#a0ffa0";
our $executedFunctionForeground = "#000000";
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
    $self->{info} = new Gtk2::Window('popup');
    $self->{info}->set_type_hint('tooltip');
    $self->{info}->set_keep_above(1);
    $self->{infobuffer} = new Gtk2::TextBuffer();
    my $infoview = Gtk2::TextView->new_with_buffer($self->{infobuffer});
    my $frame = new Gtk2::Frame();
    $frame->add($infoview);
    $frame->show_all();
    $self->{info}->add($frame);
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
sub left($$$) {
    my ($self, $widget, $event) = @_;
    $self->{info}->hide();
}

# Called when the pointer moves within the window, or when it enters
# the window.
sub motion($$$) {
    my ($self, $widget, $event) = @_;
    my $path = $self->{view}->get_path_at_pos($event->x(), $event->y());
    if(!defined $path) {
        $self->{info}->hide();
        return;
    }
    my @path = $path->get_indices();
    my $line = $path[0] + 1;
    $self->{infobuffer}->delete($self->{infobuffer}->get_bounds());
    my $af = $self->{files}->getFile($self->{current});
    my $function = $af->functionInfo($line, 'name');
    my $display = 0;
    if(defined $function) {
        $self->{infobuffer}->insert
            ($self->{infobuffer}->get_end_iter(),
             join("\n",
                  map(sprintf("Function %s\n  Called %d times returned %d%%\n  %d%% of blocks executed",
                              $_->{name},
                              $_->{called},
                              $_->{returned},
                              $_->{blocks}),
                      @$function)));
        $display = 1;
    }
    if($display) {
        $self->{info}->move($event->x_root() + 8, $event->y_root() + 8);
        $self->{info}->present();
    } else {
        $self->{info}->hide();
    }
}

# Called when the window is scrolled
sub scrolled($$$) {
    my ($self) = @_;
    # TODO we should figure out what we're looking at and update the
    # info window accordingly.
    $self->{info}->hide();
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
        my ($fg, $bg);
        my $function = $af->functionInfo($n, 'name');
        if(defined $function) {
            if($af->functionInfo($n, 'called') > 0) {
                $bg = $executedFunctionBackground;
                $fg = $executedFunctionForeground;
            } else {
                $bg = $notExecutedFunctionBackground;
                $fg = $notExecutedFunctionForeground;
            }
        } elsif($count < 0) {
            $bg = $notExecutableBackground;
            $fg = $notExecutableForeground;
        } elsif($count == 0) {
            $bg = $notExecutedBackground;
            $fg = $notExecutedForeground;
        } else {
            $bg = $executedBackground;
            $fg = $executedForeground;
        }
        $self->{model}->set($self->{model}->append(),
                            0, $n,
                            1, $count < 0 ? "-" : $count,
                            2, $text,
                            3, $bg,
                            4, $fg);
    }
    $self->{view}->scroll_to_cell(Gtk2::TreePath->new_from_indices($where));
    return $self;
}

1;
