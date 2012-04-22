package Greenend::ViewGCOV::MenuBar;
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
    my $filemenu = $self->populateMenu
        (new Gtk2::Menu(),
         $self->menuItem("Open", sub { $self->open(); }),
         $self->menuItem("Refresh", sub { $self->refresh(); }),
         $self->menuItem("Quit", sub { Gtk2->main_quit(); }));
    # TODO there should be an 'About' menu
    $self->{menubar} = $self->populateMenu
        (new Gtk2::MenuBar(),
         $self->menuItem("File", $filemenu));
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
    my $self = shift;
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
sub menuItem($$$) {
    my ($self, $label, $child) = @_;
    my $item = new Gtk2::MenuItem($label);
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

1;
