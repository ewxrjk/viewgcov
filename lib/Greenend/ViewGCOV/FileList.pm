package Greenend::ViewGCOV::FileList;
use warnings;
use strict;
use Gtk2;

our $openProgram = "gnome-open";

# new FileList()
sub new {
    my $self = bless {}, shift;
    return $self->initialize(@_);
}

# initialize()
sub initialize {
    my $self = shift;
    $self->{suppressSystemFiles} = 1;
    $self->{files} = {};
    $self->{model} = new Gtk2::ListStore('Glib::String', # display filename
                                         'Glib::String', # % string
                                         'Glib::String', # actual filename
                                         'Glib::Double'); # actual coverage
    $self->{model}->set_sort_column_id(3, 'ascending');
    $self->{view} = new Gtk2::TreeView($self->{model});
    my $namesRenderer = new Gtk2::CellRendererText();
    #$namesRenderer->set("ellipsize", 'start');
    #$namesRenderer->set("width-chars", 24);
    my $names = Gtk2::TreeViewColumn->new_with_attributes
        ("File", $namesRenderer,
        'text' => 0);
    $names->set_resizable(1);
    $names->set_sort_column_id(0);
    my $executedRenderer = new Gtk2::CellRendererText();
    $executedRenderer->set("xalign", 1);
    $executedRenderer->set("width-chars", 4);
    my $executed = Gtk2::TreeViewColumn->new_with_attributes
        ("Executed", $executedRenderer,
         'text' => 1);
    $executed->set_resizable(1);
    $executed->set_sort_column_id(3);
    $self->{view}->append_column($names);
    $self->{view}->append_column($executed);
    $self->{view}->get_selection()->signal_connect
        ('changed',
         sub { $self->selectionChanged(); });
    $self->{view}->signal_connect
        ('button-press-event',
         sub { $self->buttonPressed(@_); });
    $self->{scrolled} = new Gtk2::ScrolledWindow();
    $self->{scrolled}->set_policy('never', 'automatic');
    $self->{scrolled}->add($self->{view});
    return $self;
}

# setContents(FILECONTENTS)
#
# The object used to display file contents
sub setContents($$) {
    my $self = shift;
    $self->{contents} = shift;
}

# Return the widget to display
sub widget($) {
    my $self = shift;
    return $self->{scrolled};
}

# getFile(PATH)
#
# Return the AnnotatedFile for PATH
sub getFile($$) {
    my ($self, $path) = @_;
    return $self->{files}->{$path};
}

# getPathFromIter(ITER)
sub getPathFromIter($$) {
    my ($self, $iter) = @_;
    if(defined $iter) {
        my @values = $self->{model}->get($iter, 2);
        return $values[0];
    } else {
        return undef;
    }
}

# getSelected()
#
# Return the selected path
sub getSelected($) {
    my $self = shift;
    return $self->getPathFromIter(scalar $self->{view}->get_selection()->get_selected());
}

# Called when the selection may have changed
sub selectionChanged($) {
    my $self = shift;
    $self->{contents}->select($self->getSelected());
}

# Called when a button is pressed
sub buttonPressed($$$) {
    my ($self, $widget, $event) = @_;
    if($event->type() eq 'button-press'
       and $event->button() == 3) {
        # Select the target
        my $path = $self->{view}->get_path_at_pos($event->x(), $event->y());
        $self->{view}->get_selection()->select_path($path);
        $self->contextMenu($event, $self->getSelected());
        return 1;
    }
}

# contextMenu(EVENT, PATH)
#
# Pop up a context menu
sub contextMenu($$$) {
    my ($self, $event, $path) = @_;
    my $menu = Greenend::ViewGCOV::MenuBar::populateMenu
        (new Gtk2::Menu(),
         Greenend::ViewGCOV::MenuBar::menuItem
         ('gtk-refresh',
          sub {
              my $af = new Greenend::ViewGCOV::AnnotatedFile($path);
              if(defined $af) {
                  $self->{files}->{$path} = $af;
                  $self->{contents}->redraw();
              }
          }),
         Greenend::ViewGCOV::MenuBar::menuItem
         ('gtk-edit',
          sub {
              my $af = $self->{files}->{$path};
              system($openProgram, $af->sourcePath());
          }));
    $menu->show_all();
    $menu->popup(undef, undef, undef, 0, $event->button, $event->time)
}

# isSystemFile(PATH)
#
# Return true if PATH is a system file
sub isSystemFile($$) {
    my $self = shift;
    local $_ = shift;
    # TODO would be nice to make this configurable
    return m,^/usr/include|/usr/local/include|/sw/include,;
}

# addFile(PATH)
#
# Add one file
sub addFile($$) {
    my $self = shift;
    my $path = shift;
    # Skip files we already know about
    return if exists $self->{files}->{$path};
    # Report an error for files we cannot read
    if(!-r $path) {
        error("cannot read $path");
        return;
    }
    my $af = new Greenend::ViewGCOV::AnnotatedFile($path);
    my $sourcePath = $af->sourcePath();
    return if $self->{suppressSystemFiles} && $self->isSystemFile($sourcePath);
    $sourcePath =~ s,^\Q$self->{directory}\E/,,;
    $self->{files}->{$path} = $af;
    my $executed = $af->linesExecutedProportion();
    my $percent = int(100 * $executed);
    # Like gcov, only report 0%/100% if it's exactly that.
    if($percent == 0 && $executed > 0) { $percent = 1; }
    if($percent == 100 && $executed < 1) { $percent = 99; }
    $self->{model}->set($self->{model}->append(),
                        0, $sourcePath,
                        1, sprintf("%d%%", $percent),
                        2, $path,
                        3, $executed);
}

# addDirectory(DIR)
#
# Recursively add all *.gcov files in and below DIR
sub addDirectory($$) {
    my $self = shift;
    my $dir = shift;
    for my $file (glob("$dir/*")) {
        if(-d $file) {
            if(-r $file and -x $file) {
                $self->addDirectory($file);
            }
        } elsif($file =~ /\.gcov$/ && -r $file) {
            $self->addFile($file);
        }
    }
}

# setDirectory(DIRECTORY)
#
# Set the directory
sub setDirectory($$) {
    my $self = shift;
    my $new = shift;
    if(!-r $new || !-x $new) {
        error("$new is not readable");
        return;
    }
    if(!-d $new) {
        error("$new is not a directory");
        return;
    }
    $new =~ s,/+$,, unless $new =~ m,^/+$,;
    return if exists $self->{directory} and $new eq $self->{directory};
    $self->{directory} = $new;
    $self->{view}->get_ancestor('Gtk2::Window')->set_title("viewgcov $new");
    $self->refresh();
}

# refresh()
#
# Rescan the current directory
sub refresh($) {
    my $self = shift;
    my $selected = $self->getSelected();
    $self->{files} = {};
    $self->{model}->clear();
    $self->addDirectory($self->{directory});
    if(defined $selected) {
        # See if we can find the same file again
        for(my $iter = $self->{model}->get_iter_first();
            defined $iter;
            $iter = $self->{model}->iter_next($iter)) {
            if($selected eq $self->getPathFromIter($iter)) {
                $self->{view}->get_selection()->select_iter($iter);
                last;
            }
        }
    }
}

# error(DESCRIPTION)
#
# Report an error.
sub error($$) {
    # TODO putting it here is a bit of a hack...
    my $self = shift;
    my $description = shift;
    my $dialog = new Gtk2::MessageDialog
        ($self->{view}->get_ancestor('Gtk2::Window'),
         'destroy-with-parent',
         'error',
         'ok',
         "%s", $description);
    $dialog->run();
    $dialog->destroy();
}

1;
