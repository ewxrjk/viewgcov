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
    my $filemenu = $self->populateMenu
        (new Gtk2::Menu(),
         $self->menuItem("New Window", sub {
             my $w = new Greenend::ViewGCOV::Window();
             $w->{files}->setDirectory($self->{files}->{directory});
             $w->widget()->show_all();
         }),
         $self->menuItem("Open", sub { $self->open(); }),
         $self->menuItem("Refresh", sub { $self->refresh(); }),
         $self->menuItem("Close", sub {
             $self->{menubar}->get_ancestor('Gtk2::Window')->destroy();
                         }),
         $self->menuItem("Quit", sub { Gtk2->main_quit(); }));
    my $helpmenu = $self->populateMenu
        (new Gtk2::Menu(),
         $self->menuItem("About", sub { $self->about(); }));
    # TODO there should be an 'About' menu
    $self->{menubar} = $self->populateMenu
        (new Gtk2::MenuBar(),
         $self->menuItem("File", $filemenu),
         $self->menuItem("Help", $helpmenu));
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
