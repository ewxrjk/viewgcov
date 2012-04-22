package Greenend::ViewGCOV::FileContents;
use Gtk2;
use warnings;

our $notExecutableBackground = "#ffffff";
our $notExecutableForeground = "#808080";
our $notExecutedBackground = "#ffa0a0";
our $notExecutedForeground = "#000000";
our $executedBackground = "#ffffff";
our $executedForeground = "#000000";
# TODO above should be configurable

# new FileContents(FILELIST)
sub new {
    my $self = bless {}, shift;
    return $self->initialize(@_);
}

# initialize(FILELIST)
sub initialize {
    my $self = shift;
    $self->{files} = shift;
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
    $self->{scrolled} = new Gtk2::ScrolledWindow();
    $self->{scrolled}->set_policy('automatic', 'automatic');
    $self->{scrolled}->add($self->{view});
    return $self;
}

# Return the widget to display
sub widget($) {
    my $self = shift;
    return $self->{scrolled};
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
        $self->{model}->set($self->{model}->append(),
                            0, $n,
                            1, $count < 0 ? "-" : $count,
                            2, $text,
                            3, $count < 0 ? $notExecutableBackground
                            : $count == 0 ? $notExecutedBackground
                                          : $executedBackground,
                            4, $count < 0 ? $notExecutableForeground
                            : $count == 0 ? $notExecutedForeground
                                          : $executedForeground);
    }
    $self->{view}->scroll_to_cell(Gtk2::TreePath->new_from_indices($where));
    return $self;
}

# Called after a refresh
sub refresh($) {
    my $self = shift;
    if(defined $self->{current} and !$self->{files}->has($self->current)) {
        return $self->clear();
    } else {
        return $self->redraw();
    }
}

1;
