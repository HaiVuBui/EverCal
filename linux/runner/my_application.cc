#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static gboolean is_truthy_env(const gchar* v) {
  if (v == nullptr) return FALSE;
  gchar* s = g_ascii_strdown(v, -1);
  gboolean ok =
      (g_strcmp0(s, "1") == 0) ||
      (g_strcmp0(s, "true") == 0) ||
      (g_strcmp0(s, "yes") == 0) ||
      (g_strcmp0(s, "on") == 0);
  g_free(s);
  return ok;
}

static gboolean should_use_titlebar() {
   // For installer scripts
  // EVERCAL_TITLEBAR=1  -> titlebar/headerbar
  // EVERCAL_TITLEBAR=0  -> no decorations
  const gchar* v = g_getenv("EVERCAL_TITLEBAR");
  return is_truthy_env(v);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  const gboolean use_titlebar = should_use_titlebar();

  // Set icon explicitly
  gtk_window_set_icon_name(window, "evercal");
  gtk_window_set_default_icon_name("evercal");

  gtk_window_set_title(window, "EverCal");
  gtk_window_set_default_size(window, 900, 600);

  if (use_titlebar) {
    // Explicitly enable decorations
    gtk_window_set_decorated(window, TRUE);
    
    // CSD headerbar
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_header_bar_set_title(header_bar, "EverCal");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    // WM Mode:
    gtk_window_set_decorated(window, FALSE);
    gtk_window_set_titlebar(window, nullptr);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);

  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  const char* app_id = "com.snes.evercal";
  
  g_set_prgname(app_id);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", app_id, 
                                     "flags", G_APPLICATION_NON_UNIQUE, 
                                     nullptr));
}