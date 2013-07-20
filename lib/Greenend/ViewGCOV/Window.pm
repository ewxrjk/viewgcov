package Greenend::ViewGCOV::Window;
use warnings;
use strict;
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
    $self->{menubar} = new Greenend::ViewGCOV::MenuBar($self);
    my $vbox = new Gtk2::VBox(0, 0);
    my $vpane = new Gtk2::VPaned();
    $vpane->pack1($self->displayPanel(), 1, 1);
    $vpane->pack2($self->outputPanel(), 1, 1);
    $vbox->pack_start($self->{menubar}->widget(), 0, 0, 1);
    $vbox->pack_start($vpane, 1, 1, 1);
    $self->{window}->add($vbox);
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

# File display panel
sub displayPanel($) {
    my $self = shift;

    my $hpane = new Gtk2::HPaned();
    $self->{files} = new Greenend::ViewGCOV::FileList();
    $self->{contents} = new Greenend::ViewGCOV::FileContents();
    $self->{files}->setContents($self->{contents});
    $self->{contents}->setFiles($self->{files});
    $hpane->pack1($self->frameWidget($self->{files}->widget()), 0, 0);
    $hpane->pack2($self->frameWidget($self->{contents}->widget()), 1, 1);
    return $hpane;
}

# Compiler output panel
sub outputPanel($) {
    my $self = shift;

    $self->{outputPanel} = new Gtk2::VBox(0, 0);
    my $hbox = new Gtk2::HBox(0, 0);
    $self->{outputTitle} = new Gtk2::Label();
    $self->{outputTitle}->set_justify('left');
    $hbox->pack_start($self->{outputTitle}, 0, 0, 1);
    my $close = Gtk2::Button->new_from_stock("gtk-close");
    $close->signal_connect(clicked => sub {$self->{outputPanel}->visible(0);});
    $hbox->pack_end($close, 0, 0, 1);
    $self->{outputPanel}->pack_start($hbox, 0, 0, 1);
    my $scroller = new Gtk2::ScrolledWindow();
    $self->{output} = new Gtk2::TextView();
    $self->{output}->set_editable(0);
    my $font = new Pango::FontDescription();
    $font->set_family("monospace");
    $self->{output}->modify_font($font);
    $self->{output}->set_size_request(-1, 256);
    $scroller->add($self->{output});
    $self->{outputPanel}->pack_start($scroller, 1, 1, 1);
    $self->{outputPanel}->visible(0);
    return $self->{outputPanel};
}

1;
