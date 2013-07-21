package Greenend::ViewGCOV::MenuBar;
use warnings;
use strict;
use Greenend::ViewGCOV::Window;
use Gtk2;
use Gtk2::Gdk::Keysyms;
use Glib;
use IO::File;

# new MenuBar(FILELIST, FILECONTENTS)
sub new {
    my $self = bless {}, shift;
    return $self->initialize(@_);
}

# initialize(FILELIST, FILECONTENTS)
sub initialize {
    my $self = shift;
    $self->{window} = shift;
    my $new = menuItem("New Window", sub {
        my $w = new Greenend::ViewGCOV::Window();
        $w->{files}->setDirectory($self->{window}->{files}->{directory});
    });
    $new->add_accelerator('activate',  $self->{window}->{accelerators},
                           $Gtk2::Gdk::Keysyms{n}, 'control-mask', 'visible');
    my $open = menuItem("gtk-open", sub { $self->open(); });
    $open->add_accelerator('activate', $self->{window}->{accelerators},
                           $Gtk2::Gdk::Keysyms{o}, 'control-mask', 'visible');
    my $refresh = menuItem("gtk-refresh", sub { $self->refresh(); });
    $refresh->add_accelerator('activate',  $self->{window}->{accelerators},
                              $Gtk2::Gdk::Keysyms{F5}, [], 'visible');
    my $compile = menuItem("Compile", sub { $self->compile(); });
    $compile->add_accelerator('activate',  $self->{window}->{accelerators},
                              $Gtk2::Gdk::Keysyms{F6}, [], 'visible');
    my $runTests = menuItem("Run tests", sub { $self->runTests(); });
    $runTests->add_accelerator('activate',  $self->{window}->{accelerators},
                               $Gtk2::Gdk::Keysyms{F7}, [], 'visible');
    my $close = menuItem("gtk-close", sub { $self->{window}->{window}->destroy(); });
    $close->add_accelerator('activate',  $self->{window}->{accelerators},
                            $Gtk2::Gdk::Keysyms{w}, 'control-mask', 'visible');
    my $quit = menuItem("gtk-quit", sub { Gtk2->main_quit(); });
    $quit->add_accelerator('activate',  $self->{window}->{accelerators},
                           $Gtk2::Gdk::Keysyms{q}, 'control-mask', 'visible');
    my $about = menuItem("gtk-about", sub { $self->about(); });
    my $filemenu = populateMenu
        (new Gtk2::Menu(),
         $new,
         $open,
         $refresh,
         $compile,
         $runTests,
         $close,
         $quit);
    my $helpmenu = populateMenu
        (new Gtk2::Menu(),
         $about);
    $self->{menubar} = populateMenu
        (new Gtk2::MenuBar(),
         menuItem("File", $filemenu),
         menuItem("Help", $helpmenu));
    return $self;
    # TODO Compile/Run Tests should be greyed out when underway
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
    $chooser->set_current_folder($self->{window}->{files}->{directory});
    $self->{window}->{files}->setDirectory($chooser->get_filename())
        if $chooser->run() eq 'ok';
    $chooser->destroy();
}

sub command {
    my $self = shift;
    my $title = shift;
    my $cmd = shift;
    my $complete = shift;
    return if(exists $self->{subprocess});
    if(ref $cmd ne 'ARRAY') {
        $cmd = [$cmd];
    }
    $cmd = join(";", map(("echo \Q> $_\E", $_), @$cmd));
    $self->{subprocess} = IO::File->new("exec 2>&1;$cmd|");
    $self->{subprocess}->blocking(0);
    my $buffer = $self->{window}->{output}->get_buffer();
    my ($start, $end) = $buffer->get_bounds();
    $buffer->delete($start, $end);
    Glib::IO->add_watch($self->{subprocess}->fileno,
                        [qw(in hup)],
                        sub { return $self->readable($complete, $title); });
    $self->{window}->{outputTitle}->set_label("$title (running...)");
    $self->{window}->{outputPanel}->visible(1);
}

sub readable($) {
    my $self = shift;
    my $complete = shift;
    my $title = shift;
    my $buffer = $self->{window}->{output}->get_buffer();
    my $input;
    my $bytes = sysread($self->{subprocess}, $input, 4096);
    if(!defined $bytes || $bytes == 0) {
        $self->{window}->{outputTitle}->set_label("$title (complete)");
        delete $self->{subprocess};
        if(defined $complete) {
            &$complete();
        }
        return 0;
    }
    my ($start, $end) = $buffer->get_bounds();
    $buffer->insert($end, $input);
    $buffer->move_mark($buffer->get_mark('insert'), $end);
    $self->{window}->{output}->scroll_to_mark($buffer->get_insert(),
                                              0, 0, 1, 1);
    return 1;
}

sub compile($) {
    my $self = shift;
    my $files = $self->{window}->{files};
    $self->command("Compiler output",
                   "make -C \Q$files->{directory}\E");
}

sub runTests($) {
    my $self = shift;
    my $files = $self->{window}->{files};
    my @cmd = ("find \Q$files->{directory}\E '(' -name '*.gcda' -o -name '*.gcov' ')' -delete",
               "make -C \Q$files->{directory}\E check",
               "find \Q$files->{directory}\E '(' -name '*.[ch]' -o -name '*.cc' -o -name '*.hh' ')' -execdir gcov -a -b -u '{}' +");

    $self->command("Test output",
                   \@cmd,
                   sub { $files->refresh(); });
    # TODO should be a way to interrupt this if a test hangs
}

sub refresh($) {
    my $self = shift;
    my $files = $self->{window}->{files};
    my @cmd = ("find \Q$files->{directory}\E '(' -name '*.[ch]' -o -name '*.cc' -o -name '*.hh' ')' -execdir gcov -a -b -u '{}' +");
    $self->command("Gcov output",
                   \@cmd,
                   sub { $files->refresh(); });
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
