package Greenend::ViewGCOV::Window;
use warnings;
use Gtk2;
use Greenend::ViewGCOV::FileList;
use Greenend::ViewGCOV::FileContents;
use Greenend::ViewGCOV::MenuBar;

my $windowCount;

# new Window()
sub new {
    my $self = bless {}, shift;
    return $self->initialize(@_);
}

sub initialize($) {
    my $self = shift;
    ++$windowCount;
    $self->{window} = new Gtk2::Window('toplevel');
    $self->{window}->signal_connect(destroy => sub {
        Gtk2->main_quit() if !--$windowCount;
    });
    $self->{files} = new Greenend::ViewGCOV::FileList();
    $self->{contents} = new Greenend::ViewGCOV::FileContents();
    $self->{files}->setContents($self->{contents});
    $self->{contents}->setFiles($self->{files});
    $self->{menubar} = new Greenend::ViewGCOV::MenuBar
        ($self->{files}, $self->{contents});
    my $box = new Gtk2::VBox(0, 0);
    $box->pack_start($self->{menubar}->widget(), 0, 0, 1);
    my $pane = new Gtk2::HPaned();
    $pane->pack1($self->frameWidget($self->{files}->widget()), 0, 0);
    $pane->pack2($self->frameWidget($self->{contents}->widget()), 1, 1);
    $box->pack_start($pane, 1, 1, 1);
    $self->{window}->add($box);
    return $self;
}

# Return the widget to display
sub widget($) {
    my $self = shift;
    return $self->{window};
}

# Frame a widget
sub frameWidget($) {
    my $self = shift;
    my $child = shift;
    my $frame = new Gtk2::Frame();
    $frame->set_shadow_type('in');
    $frame->add($child);
    return $frame;
}

1;
