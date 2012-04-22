package Greenend::ViewGCOV::MenuBar;
use Greenend::ViewGCOV::Window;
use Gtk2;
use warnings;

# new MenuBar(FILELIST, FILECONTENTS)
sub new {
    my $self = bless {}, shift;
    return $self->initialize(@_);
}

# initialize(FILELIST, FILECONTENTS)
sub initialize {
    my $self = shift;
    $self->{files} = shift;
    $self->{contents} = shift;
    my $filemenu = populateMenu
        (new Gtk2::Menu(),
         menuItem("New Window", sub {
             my $w = new Greenend::ViewGCOV::Window();
             $w->{files}->setDirectory($self->{files}->{directory});
             $w->widget()->show_all();
         }),
         menuItem("gtk-open", sub { $self->open(); }),
         menuItem("gtk-refresh", sub { $self->refresh(); }),
         menuItem("gtk-close", sub {
             $self->{menubar}->get_ancestor('Gtk2::Window')->destroy();
                         }),
         menuItem("gtk-quit", sub { Gtk2->main_quit(); }));
    my $helpmenu = populateMenu
        (new Gtk2::Menu(),
         menuItem("gtk-about", sub { $self->about(); }));
    $self->{menubar} = populateMenu
        (new Gtk2::MenuBar(),
         menuItem("File", $filemenu),
         menuItem("Help", $helpmenu));
    return $self;
}

# Return the widget to display
sub widget($) {
    my $self = shift;
    return $self->{menubar};
}

# populateMenu(SHELL, ITEM...)
#
# Add each ITEM to SHELL.  ITEMs can be menu items or submenus.
sub populateMenu {
    my $shell = shift;
    for my $item (@_) { $shell->append($item); }
    return $shell;
}

# menuItem(LABEL, CHILD)
#
# Create a Gtk2::MenuItem with label LABEL.
# If CHILD is code then it will be executed when the item is activated
# Otherwise CHILD must be a submenu.
#
# Returns the menu item.
sub menuItem($$) {
    my ($label, $child) = @_;
    my $item;
    if($label =~ /^gtk-/) {
        $item = Gtk2::ImageMenuItem->new_from_stock($label);
    } else {
        $item = new Gtk2::MenuItem($label);
    }
    if(ref $child eq 'CODE') { $item->signal_connect("activate" => $child); }
    else { $item->set_submenu($child); }
    return $item;
}

sub open($) {
    my $self = shift;
    my $chooser = new Gtk2::FileChooserDialog
        ("Select directory",
         $self->{menubar}->get_ancestor('Gtk2::Window'),
         'select-folder',
         'gtk-cancel' => 'cancel',
         'gtk-ok' => 'ok');
    $self->{files}->setDirectory($chooser->get_filename())
        if $chooser->run() eq 'ok';
    $chooser->destroy();
}

sub refresh($) {
    my $self = shift;
    $self->{files}->refresh();
}

sub about($) {
    my $self = shift;
    my $dialog = new Gtk2::MessageDialog
        ($self->{menubar}->get_ancestor('Gtk2::Window'),
         'destroy-with-parent',
         'info',
         'ok',
         "viewgcov $main::VERSION");
    $dialog->run();
    $dialog->destroy();
}

1;
